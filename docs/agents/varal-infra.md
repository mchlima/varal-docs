## Este repositório: varal-infra

Infraestrutura do Varal: Docker Compose de produção no VPS, configuração do Varal no NGINX compartilhado (HTTPS de origem, proxy para a API e servidor dos builds dos apps), atrás do Cloudflare (DNS, proxy e HTTPS público), backup do PostgreSQL e o Postgres de desenvolvimento compartilhado pelos worktrees da API. Spec principal: 01, seções 4 e 4.1.

### Comandos

Ainda não há arquivos. Quando forem criados, registre aqui como subir o Postgres de desenvolvimento, validar a configuração do NGINX, e fazer deploy.

### Regras deste repositório

- **Produção:** nenhuma mudança é aplicada no VPS sem pedido explícito do usuário. Este repositório descreve a infraestrutura; aplicar é uma ação à parte.
- **Tudo em Docker:** no VPS, tudo roda em container; nada é instalado direto no host. O PostgreSQL e o proxy NGINX do VPS são **compartilhados com outros projetos** e ficam fora deste repositório (o PostgreSQL em `/opt/postgres` e o NGINX em `/opt/nginx`, ambos descritos na spec 01, seção 4). O Compose de produção do Varal não define `nginx` nem `postgres`: a API entra nas redes Docker externas `postgres` e `proxy`, usa banco e usuário `varal`, e o Varal entra no proxy com um `server` por host. Nunca altere, reinicie ou recrie os serviços compartilhados nem mexa na configuração de outros projetos sem pedido explícito; para aplicar mudanças no NGINX, valide (`nginx -t`) e recarregue (`nginx -s reload`), nunca reinicie.
- **Cloudflare:** os hosts do Varal ficam com proxy ligado e SSL Full (strict). O NGINX usa o Cloudflare Origin Certificate curinga de `/opt/nginx/certs/kratinho.com.br/`, nunca o certbot, e restaura o IP real pelo `CF-Connecting-IP` (spec 01, RN-01.18 e RN-01.19). Certificados e chaves nunca entram no repositório.
- **Hosts:** `varal.kratinho.com.br` (front do painel), `admin-varal.kratinho.com.br` (front do admin) e `api-web-varal.kratinho.com.br` (API). Os arquivos de cada host ficam em `nginx/conf.d/` e são copiados para `/opt/nginx/conf.d/` (passo a passo em `nginx/README.md`).
- **Segredos** nunca entram no repositório: só `.env.example` com nomes e descrições.
- **Versões, não código:** o Compose de produção referencia imagens ou builds dos outros repositórios por tag; não copie código deles para cá.
- **Postgres de desenvolvimento** (`dev/compose.yml`, projeto `varal-dev-db`): é compartilhado por todos os worktrees de todos os agentes. Nunca rode `docker compose down -v`, apague o volume nem recrie o container sem pedido explícito, porque isso destrói os bancos de todos.
- **Backup:** fora do MVP por enquanto (spec 01, seção 4). Quando entrar, vem com o procedimento de restauração testado e documentado.

Escopos de commit adicionais: `nginx`, `compose`, `backup`, `dev`, `deploy`.
