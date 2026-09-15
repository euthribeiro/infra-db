# infra-db — Infraestrutura do Banco de Dados Gerenciado

Terraform que provisiona o **PostgreSQL gerenciado (Amazon RDS)** do Wrench Auto Repair, o role
de menor privilégio que a aplicação usa para se conectar e o role somente leitura da Lambda de
autenticação.

FIAP · Pós-Tech · 13SOAT · Tech Challenge Fase 3 · Grupo **BGT³**

## Propósito

Separar o ciclo de vida do dado do ciclo de vida da plataforma. O cluster EKS pode ser destruído e
recriado sem tocar no banco; o banco pode ser redimensionado sem plano da infraestrutura inteira.

| Repositório | Conteúdo |
|---|---|
| **infra-db** (este) | RDS PostgreSQL e role da aplicação |
| `infra-k8s` | VPC, EKS, ACM, ECR, DNS, SES |
| `app-k8s` | API .NET e chart Helm |
| `lambda-auth` | Function serverless de autenticação e API Gateway |

## Arquitetura

```mermaid
flowchart LR
    subgraph infra["infra-k8s (remote state)"]
        vpc["VPC + subnets públicas"]
    end

    subgraph rds_stack["stack rds/ — workspace wrench_auto_repair_rds"]
        sg["Security Group :5432"]
        sng["DB Subnet Group"]
        db[("RDS PostgreSQL 18<br/>db.t4g.micro · 20 GB<br/>backup 7 dias")]
        cname["CNAME prod-db.bgt3.com.br"]
    end

    subgraph roles_stack["stack roles/ — workspace wrench_auto_repair_postgres"]
        role["Role da aplicação<br/>(menor privilégio)"]
        rolelambda["Role wrench_lambda_auth<br/>(SELECT por coluna)"]
    end

    app["app-k8s<br/>API .NET"]
    lambda["lambda-auth<br/>autenticação por CPF"]

    vpc -.->|"vpc_id, public_subnet_ids"| sg
    vpc -.-> sng
    sng --> db
    sg --> db
    db --> cname
    db -.->|"database_address"| role
    db -.-> rolelambda
    app -->|"EF Core · TLS 5432"| cname
    lambda -->|"EF Core somente leitura · TLS 5432"| cname
```

## Por que dois stacks

O provider `postgresql` precisa do endpoint do banco **na configuração do provider**, que o
Terraform resolve antes do `apply`. Um provider não pode depender de um recurso criado no mesmo
plano, então instância e role não cabem no mesmo state:

| Stack | Workspace HCP | Responsabilidade |
|---|---|---|
| `terraform/rds` | `wrench_auto_repair_rds` | Instância RDS, DB subnet group, security group e CNAME |
| `terraform/roles` | `wrench_auto_repair_postgres` | Role da aplicação e role somente leitura da Lambda de autenticação |

O stack `roles/` lê `database_address` e `database_name` do state do `rds/` via
`terraform_remote_state`.

`superuser = false` é obrigatório na configuração do provider: o usuário master do RDS não é um
superusuário PostgreSQL de verdade, e sem essa flag o provider emite comandos que falham.

O stack `roles/` alcança o RDS pelo endpoint público (`publicly_accessible = true` e security group
liberado), porque roda em execução remota no HCP. Não há *default privileges*: a aplicação é Code
First e as tabelas são criadas pelo próprio role da aplicação, que é o dono delas.

## Role da Lambda de autenticação

A Lambda do repositório `lambda-auth` consulta existência e status do cliente com um role próprio,
`wrench_lambda_auth`, que só enxerga as colunas de que precisa:

| Tabela | Colunas com `SELECT` |
|---|---|
| `public."Clientes"` | `Id`, `Documento`, `Email` |
| `public."Usuarios"` | `Id`, `Email`, `PerfilId`, `Ativo` |
| `public."Perfis"` | `Id`, `Nome` |

Senha, telefone, endereço e nome do cliente ficam fora do alcance da function. Essas colunas são o
contrato entre a Lambda e a API; o `app-k8s` tem um teste que falha se uma migration as alterar.

Duas restrições definem como os grants são aplicados:

1. **Quem concede é o dono das tabelas.** O usuário master cria o role e concede `CONNECT` e
   `USAGE`, mas no RDS ele não é superusuário nem dono das tabelas. Os grants por coluna usam o
   provider `postgresql.aplicacao`, que conecta com o role da aplicação — o dono das tabelas.
2. **As tabelas precisam existir.** Elas são criadas pelas migrations no primeiro deploy do
   `app-k8s`. Por isso os grants por coluna ficam atrás da variável
   `lambda_auth_column_grants_enabled`, falsa por padrão.

Ordem na primeira subida:

1. `infra-db` com `LAMBDA_AUTH_COLUMN_GRANTS_ENABLED` ausente ou `false` — cria os dois roles.
2. `app-k8s` — primeiro deploy, que aplica as migrations.
3. Definir a variable `LAMBDA_AUTH_COLUMN_GRANTS_ENABLED=true` e reexecutar este pipeline
   (`workflow_dispatch`) — aplica os grants por coluna.
4. `lambda-auth` — deploy da function.

## Tecnologias

- Terraform >= 1.5 com backend HCP Terraform (organização `bgt3`)
- Providers: AWS ~> 6.0, Cloudflare ~> 5.0, `cyrilgdn/postgresql`
- Amazon RDS PostgreSQL 18
- GitHub Actions

## Como executar

```bash
terraform login

cd terraform/rds
terraform init
terraform apply \
  -var="rds_database_username=<master>" \
  -var="rds_database_password=<senha>"

cd ../roles
terraform init
terraform apply \
  -var="application_database_username=<app>" \
  -var="application_database_password=<senha>" \
  -var="rds_master_username=<master>" \
  -var="rds_master_password=<senha>" \
  -var="lambda_auth_database_password=<senha>" \
  -var="lambda_auth_column_grants_enabled=true"
```

## Deploy

| Gatilho | O que acontece |
|---|---|
| Pull request para `master` | `fmt -check`, `init` e `validate` dos dois stacks |
| Push em `master` | `apply` do `rds/` e, em seguida, do `roles/` |
| `workflow_dispatch` | Mesmo fluxo, sob demanda |

O `roles/` depende do `rds/` no mesmo workflow (`needs`), garantindo que a instância exista antes
da tentativa de conexão.

### Variáveis e secrets

| Nome | Tipo | Descrição |
|---|---|---|
| `TF_API_TOKEN` | secret | Token do HCP Terraform |
| `RDS_MASTER_USERNAME` / `RDS_MASTER_PASSWORD` | secret | Usuário master do RDS |
| `APPLICATION_DATABASE_USERNAME` / `APPLICATION_DB_PASSWORD` | secret | Role de menor privilégio da aplicação |
| `LAMBDA_AUTH_DB_USERNAME` / `LAMBDA_AUTH_DB_PASSWORD` | secret | Role somente leitura da Lambda de autenticação; os mesmos valores vão para o `lambda-auth` |
| `LAMBDA_AUTH_COLUMN_GRANTS_ENABLED` | variable | `true` depois do primeiro deploy do `app-k8s`; habilita o `SELECT` por coluna |
| `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ZONE_ID` | secret | CNAME `prod-db` |

## Migração de state vinda do monorepo

Na Fase 2 o `aws_db_instance.wrench_db`, o `aws_db_subnet_group.rds`, o
`aws_security_group.allow_postgres_traffic` e o `cloudflare_dns_record.db` viviam no state
`wrench_auto_repair` (repositório `infra-k8s`). Este repositório passou a declará-los.

**Situação verificada em 2026-09-02:** o state do `infra-k8s` não contém nenhum recurso de banco —
o RDS foi destruído ao fim da Fase 2. Não há state a migrar. O workspace
`wrench_auto_repair_rds` já foi criado no projeto *Wrench Auto Repair* e o compartilhamento de
state está ativo no nível do projeto.

Faltam duas coisas antes do primeiro `apply`: definir as variáveis sensíveis no workspace e
reconciliar o state residual do `wrench_auto_repair_postgres`, que ainda descreve o role de um
banco que não existe mais. Ambas estão detalhadas em
[`docs/migracao-de-state.md`](./docs/migracao-de-state.md), junto com o procedimento completo caso
a separação precise ser refeita com uma instância viva.
