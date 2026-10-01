## Este repositório: varal-infra

Infraestrutura do Varal: Docker Compose de produção no VPS, NGINX (HTTPS, proxy para a API e servidor dos builds dos apps), backup do PostgreSQL e o Postgres de desenvolvimento compartilhado pelos worktrees da API. Spec principal: 01, seções 4 e 4.1.

### Comandos

Ainda não há arquivos. Quando forem criados, registre aqui como subir o Postgres de desenvolvimento, validar a configuração do NGINX, fazer deploy e restaurar um backup.

### Regras deste repositório

- **Produção:** nenhuma mudança é aplicada no VPS sem pedido explícito do usuário. Este repositório descreve a infraestrutura; aplicar é uma ação à parte.
- **Segredos** nunca entram no repositório: só `.env.example` com nomes e descrições.
- **Versões, não código:** o Compose de produção referencia imagens ou builds dos outros repositórios por tag; não copie código deles para cá.
- **Postgres de desenvolvimento** (`dev/compose.yml`, projeto `varal-dev-db`): é compartilhado por todos os worktrees de todos os agentes. Nunca rode `docker compose down -v`, apague o volume nem recrie o container sem pedido explícito, porque isso destrói os bancos de todos.
- **Backup:** toda mudança no backup vem com o procedimento de restauração testado e documentado.

Escopos de commit adicionais: `nginx`, `compose`, `backup`, `dev`, `deploy`.
