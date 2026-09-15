# Migração do state do RDS: de `infra-k8s` para `infra-db`

Na Fase 2 a instância RDS era declarada dentro do stack da infraestrutura Kubernetes. A Fase 3
exige um repositório dedicado à infraestrutura de banco gerenciado, então quatro recursos mudaram
de state.

| Recurso | State de origem (`wrench_auto_repair`) | State de destino (`wrench_auto_repair_rds`) |
|---|---|---|
| Instância RDS | `aws_db_instance.wrench_db` | `aws_db_instance.wrench_db` |
| DB subnet group | `aws_db_subnet_group.rds` | `aws_db_subnet_group.rds` |
| Security group | `aws_security_group.allow_postgres_traffic` | `aws_security_group.allow_postgres_traffic` |
| CNAME `prod-db` | `cloudflare_dns_record.db` | `cloudflare_dns_record.db` |

## Situação verificada em 2026-09-02

O state do workspace `wrench_auto_repair` foi inspecionado e **não contém nenhum recurso de
banco**. O que restou lá é a base de rede e o certificado:

```
aws_vpc.vpc_wrench
aws_subnet.public_subnet (x3)
aws_internet_gateway.igw
aws_acm_certificate.app
data.aws_availability_zones.available
```

Ou seja: a instância RDS, o DB subnet group, o security group do Postgres e o CNAME `prod-db` já
foram destruídos junto com o resto da infraestrutura ao fim da Fase 2. **Não há state a migrar.**
Vale a Opção A — que já foi executada; ver [Passos executados](#passos-executados).

O aviso abaixo continua registrado porque volta a valer se, por qualquer motivo, uma instância RDS
for provisionada pelo `infra-k8s` antes desta separação estar consolidada.

> ⚠️ **Aplicar `infra-k8s` com uma instância RDS viva no state dele a destrói sem snapshot final**
> (`skip_final_snapshot = true`), porque a instância não está mais declarada naquela configuração.
> Antes de qualquer `apply` nessa situação, tire um snapshot manual:
>
> ```bash
> aws rds create-db-snapshot \
>   --db-instance-identifier db-wrench-auto-repair \
>   --db-snapshot-identifier db-wrench-pre-split-$(date +%Y%m%d)
> ```

## Passos executados

- [x] Workspace `wrench_auto_repair_rds` criado na organização `bgt3`, no projeto
      **Wrench Auto Repair** (`prj-zZXSjHgEWpASRDZz`), modo de execução remoto, sem VCS
      (CLI-driven, igual aos demais).
- [x] Compartilhamento de state confirmado: o projeto usa `project-remote-state = true`, então os
      workspaces do projeto leem o state uns dos outros sem configuração de consumidor
      individual. O novo workspace foi movido para esse projeto e teve a mesma opção habilitada.
- [x] Confirmado que o state de origem não contém recurso de banco.

## Passos pendentes (exigem segredos ou decisão)

### 1. Variáveis do workspace `wrench_auto_repair_rds`

Definir como *Terraform Variables* marcadas como **sensitive**:

| Variável | Conteúdo |
|---|---|
| `rds_database_username` | usuário master do RDS |
| `rds_database_password` | senha do usuário master |
| `cloudflare_api_token` | token com permissão `Zone.DNS:Edit` |
| `cloudflare_zone_id` | zone ID de `bgt3.com.br` |

Alternativamente, passe-as por `-var` no pipeline — é o que o `ci-cd.yml` do `infra-db` faz para
usuário e senha, a partir dos secrets `RDS_MASTER_USERNAME` e `RDS_MASTER_PASSWORD`.

### 2. State residual do `wrench_auto_repair_postgres`

Esse workspace ainda tem **6 recursos no state** (`postgresql_role.app` e os quatro
`postgresql_grant.*`, mais o data source do remote state) apontando para um banco que não existe
mais. Duas saídas, nesta ordem de preferência:

**a) Deixar o Terraform reconciliar.** Depois que o `rds/` criar a instância nova, rode
`terraform plan` no `roles/`. O refresh não vai encontrar o role no servidor e o plano deve
propor recriá-lo. Se o plano sair limpo, aplique.

**b) Zerar o state, se o refresh falhar.** Se o provider `postgresql` não conseguir sequer
conectar durante o refresh, remova os recursos órfãos antes:

```bash
cd terraform/roles
terraform init
terraform state rm postgresql_grant.tables
terraform state rm postgresql_grant.sequences
terraform state rm postgresql_grant.schema
terraform state rm postgresql_grant.database
terraform state rm postgresql_role.app
```

Nenhum desses comandos toca em recurso real — o banco que eles descreviam já não existe.

### 3. Ordem do primeiro apply

```
1. infra-k8s    terraform/infra   # completa a VPC e o cluster
2. infra-db     terraform/rds     # cria a instância e o database de produção
3. infra-db     terraform/roles   # roles da API e da Lambda e o database de homologação
4. app-k8s      deploy develop    # migrations criam as tabelas em wrench_auto_repair_hml
5. app-k8s      deploy master     # migrations criam as tabelas em wrench_auto_repair
6. infra-db     terraform/roles   # LAMBDA_AUTH_GRANTS_* = true: SELECT por coluna para a Lambda
7. lambda-auth  deploy            # Lambdas e API Gateway de cada ambiente
```

O role da Lambda recebe `GRANT SELECT` apenas nas colunas `Clientes(Id, Documento, Email)`,
`Usuarios(Id, Email, PerfilId, Ativo)` e `Perfis(Id, Nome)`, em cada database cuja flag estiver
ligada. O PostgreSQL só aceita concessão por coluna em tabela existente, e as tabelas são criadas
pelas migrations da API; por isso o passo 6 vem depois dos passos 4 e 5.

A destruição segue a ordem inversa: `lambda-auth`, `app-k8s`, `infra-db` (`roles/` e depois `rds/`)
e, por último, `infra-k8s`.

O `rds/` depende de `vpc_id` e `public_subnet_ids` do `infra-k8s`. O output `public_subnet_ids` é
novo desta fase, então o `infra-k8s` precisa ser aplicado **antes** do `rds/` — mesmo que a VPC já
exista, o output só passa a constar no state depois de um apply.

## Procedimento completo (Opção B — banco em uso)

Mantido para referência, caso a separação precise ser refeita com uma instância viva.

`terraform state mv` não move entre workspaces do HCP. O caminho é remover do state de origem e
importar no de destino:

```bash
# --- no repositório infra-k8s, ainda com rds.tf presente ---
cd terraform/infra
terraform init

terraform state show aws_db_instance.wrench_db | grep -E '^\s+(id|arn|address)'
terraform state show aws_db_subnet_group.rds | grep -E '^\s+(id|name)'
terraform state show aws_security_group.allow_postgres_traffic | grep -E '^\s+id'
terraform state show cloudflare_dns_record.db | grep -E '^\s+id'

terraform state rm aws_db_instance.wrench_db
terraform state rm aws_db_subnet_group.rds
terraform state rm aws_security_group.allow_postgres_traffic
terraform state rm cloudflare_dns_record.db
```

```bash
# --- no repositório infra-db ---
cd terraform/rds
terraform init

terraform import aws_db_subnet_group.rds                    wrench-auto-repair-rds
terraform import aws_security_group.allow_postgres_traffic  <sg-id>
terraform import aws_db_instance.wrench_db                  db-wrench-auto-repair
terraform import cloudflare_dns_record.db                   <zone-id>/<record-id>
```

Confirme que `terraform plan` devolve **`No changes`**. Qualquer `destroy` ou `replace` no plano
significa que a importação divergiu da configuração — pare e ajuste antes de aplicar.

Só depois disso mergeie a remoção do `rds.tf` no `infra-k8s`: o `plan` de lá deve mostrar apenas
a remoção dos outputs `database_*`, nenhum `destroy` de recurso.
