<div align="center">

<img src="docs/img/cover.png" alt="Security Engineer" width="168">

# Security Engineer

**O engenheiro de segurança de software que o seu projeto nunca teve.**

Treze camadas, todas decididas. Todo controle obrigatório sai com uma checagem que prova que ele
funciona. E tudo isso enquanto o conserto ainda cabe numa linha de configuração, em vez de virar
migração, troca de chaves e pedido de desculpas para o seu usuário.

Quase toda ferramenta de segurança chega depois que o sistema está pronto e devolve uma lista de
problemas. Esta trabalha de outro jeito: fica junto enquanto o sistema é desenhado e construído para
ele já nascer certo desde o início.

![Licenca MIT](https://img.shields.io/badge/licenca-MIT-black)
![Skill de agente](https://img.shields.io/badge/tipo-skill%20de%20agente-blue)
![Versao 1.1.0](https://img.shields.io/badge/versao-1.1.0-black)
![Atualizado 17-08-2026](https://img.shields.io/badge/atualizado-17--08--2026-brightgreen)

<sub>Última atualização <b>17/08/2026 10:33 (UTC-3)</b>, versão <b>1.1.0</b></sub>

[English](README.md)

</div>

---

> **Sobre este arquivo.** A skill é escrita em inglês, para poder ser mantida e usada no mundo todo.
> Este é o README traduzido. Na prática, você usa a skill inteira em português: ela responde no
> idioma em que você falar com ela.

---

## Como ela funciona

**Ela lê o seu projeto antes de falar qualquer coisa.** Manifestos e lockfiles, configuração de
infraestrutura, schema e migrations do banco, o pipeline de deploy e o histórico completo do Git.
Ela também lê o contexto que o seu assistente já carrega: memória persistente e arquivos de
instrução sobre os seus projetos, as suas contas e decisões que você já tomou antes, para não vir
discutir algo que você já resolveu. A partir daí ela responde quatro perguntas: que tipo de sistema
é esse (serverless gerenciado, um servidor que você opera, um app de celular, uma ferramenta local),
quão sensível é o dado, quão exposto ele está, e o que um atacante leva embora se comprometer tudo.
Essas quatro respostas justificam cada exigência que vem depois.

**Ela usa as ferramentas que você já tem, e confere a configuração de verdade.** Metade da postura
de segurança de um sistema não está no repositório. Está num botão de painel. Se a row security está
mesmo ligada, se o cadastro público está mesmo desligado, se existe mesmo proteção de branch, se o
preview está mesmo protegido, se existe mesmo teto de gasto: nada disso aparece no código, e o
padrão da plataforma costuma ser o inseguro.

Então ela vai lá olhar, usando o acesso que a sua sessão já tem: um MCP conectado daquele provedor,
a CLI em que você já está logado, ou automação de navegador com a sessão autenticada, para o que só
existe no painel. Controle de versão, hospedagem e borda, plataforma de banco, provedor de
identidade, pagamento, registrador de domínio, observabilidade, conta de nuvem ou servidor, e o que
mais o seu projeto de fato usar. O `references/live-surfaces.md` cita provedores conhecidos como
exemplo resolvido, não como lista de compatibilidade: cada checagem é escrita pelo que a
configuração faz, então vale igual para o que você usar no lugar. Antes da primeira chamada ela
confirma para qual conta e qual organização está apontando, porque quase todo mundo tem mais de uma.
Configuração verificada vale mais que suposição confiante, sempre.

**E o que ela não conseguir alcançar, ela pede para você.** É essa parte que decide o quanto o
trabalho todo vale: o que ela consegue proteger é limitado pelo que ela consegue enxergar. Então,
depois de ler sozinha tudo que dava para ler, ela te diz na lata o que alcançou, o que não alcançou,
e o que cada peça que falta permitiria conferir. Sua conta de hospedagem, sua plataforma de banco,
sua organização no controle de versão, seu provedor de pagamento, seu registrador de domínio, suas
ferramentas de observabilidade, seu servidor se você tiver um.

Passe o que for cômodo: uma ferramenta conectada, uma CLI onde você já está logado, um navegador
onde você já está autenticado, um token só de leitura, ou o print de uma tela de configuração. Ela
pede acesso **só de leitura**, porque verificar nunca precisa de escrita, e mudar qualquer coisa é
outra conversa. Se você negar alguma coisa, tudo bem: aquela camada fica marcada como pendente de
verificação manual, com o motivo, você recebe uma instrução curta para conferir por conta própria, e
o trabalho segue. O que ela não vai fazer é ficar calada sobre um ponto cego, porque silêncio em
plano de segurança é lido como aprovação.

**Aí ela percorre treze camadas e registra uma decisão em cada uma:**

| | | |
|---|---|---|
| Frontend | Backend e API | Banco de dados |
| Identidade e autorização | Infraestrutura e rede | Borda: CDN, TLS, DNS, e-mail |
| Observabilidade | Pipeline de CI/CD | Segredos |
| Dependências e supply chain | Exposição pública | Privacidade e conformidade |
| Pagamentos e integrações | | |

Uma décima quarta entra só quando o sistema tem recurso de IA ou de agente. Para cada camada ela
escreve o que foi decidido, se aquilo é obrigatório ou apenas recomendado **para este sistema**, e a
checagem que prova que está valendo. Camada que realmente não se aplica fica registrada como não
aplicável, com o motivo, para ninguém precisar adivinhar depois se aquilo foi resolvido ou
esquecido.

**Depois ela fica junto durante a construção.** Toda feature que encosta em dado, identidade,
dinheiro, arquivo ou rede passa por cinco padrões antes de contar como pronta. E antes do primeiro
deploy em produção existe um portão que trava a subida, cobrindo o que um atacante automatizado
alcança na primeira hora.

**E ela conserta, se você quiser.** O relatório não é o fim do trabalho. Você dá a palavra e ela
escreve as policies, a validação, os testes, os cabeçalhos e os passos de pipeline, e muda as
configurações no ar que precisam ser mudadas, usando o mesmo acesso com que inspecionou. Cada
mudança é mostrada e combinada uma a uma, o que é irreversível ou gera cobrança é confirmado de novo
mesmo que a anterior já tenha sido aprovada, e depois de aplicar ela relê a configuração e roda a
checagem, porque conserto aplicado que ninguém verificou é promessa, não conserto. Só quer o
relatório? Ela para no plano.

O resultado é um plano que um fundador não técnico consegue ler e que um engenheiro consegue
executar: o que precisa ser verdade, em que ordem, com a mudança exata e o comando que prova que
funcionou.

---

## Por que isto existe

Os problemas caros não são os que aparecem no fim. São os que o sistema já **nasce** com eles, no
primeiro dia, em decisões que parecem configuração de rotina:

- **O banco é criado com row-level security desligada,** que é o padrão da maioria das plataformas
  gerenciadas, e o produto inteiro é construído em cima disso. A chave que está no seu JavaScript
  vira um dump completo da sua tabela de clientes, e ninguém descobre até alguém tentar.
- **Uma biblioteca é escolhida numa tarde pela velocidade de entrega,** carregando um comportamento
  que ninguém conferiu: token de sessão guardado onde qualquer script lê, escape desligado por
  padrão, um montador de query que concatena numa boa.
- **Uma dependência roda código na hora da instalação,** e ninguém olhou a manutenção dela, o peso
  transitivo nem o histórico.
- **O arquivo de ignore chega depois do primeiro commit,** então já tem chave no histórico. Apagar o
  arquivo depois não muda nada, porque é o histórico que os robôs leem.
- **O módulo de identidade vem com cadastro público ligado,** e o produto nem usa cadastro, então
  ninguém desliga. Vira remetente de spam de graça e queima o seu domínio de e-mail.
- **Os deploys de preview se publicam sozinhos,** apontam para o banco de produção e ainda anunciam
  o próprio endereço em log público de certificado.

Nada disso é bug. São decisões. E quando uma delas cobra a conta, desfazer custa uma migração, uma
troca de credencial e a reescrita de tudo que foi construído por cima.

**A outra metade é cobertura.** Na correria do prazo, a camada de aplicação leva toda a atenção e o
resto evapora em silêncio: cabeçalhos de segurança, segundo fator nas contas que fazem deploy e
gastam dinheiro, o alerta que deveria disparar quando uma autorização é negada, o direito de
exclusão e de exportação, as dependências em dia, o que aquele upload realmente contém. Não é por
falta de saber. É porque ninguém percorreu a lista.

São três hábitos que fecham as duas metades, e esta skill não abre mão de nenhum:

1. **Toda camada recebe uma decisão.** As treze de cima, todas as vezes, para que nada sobreviva
   simplesmente por nunca ter sido olhado. Nada fica em branco, porque é no branco que a falha se
   esconde.
2. **Todo controle obrigatório vem com uma checagem que o prova.** Executável, específica e amarrada
   ao momento em que deve rodar. Se você não sabe dizer como verificar, você não escreveu um
   controle, escreveu um desejo.
3. **Primeiro vem a proteção que ninguém sente.** Controle invisível antes de fricção, sempre.
   Segurança que atrapalha o produto é removida na primeira sexta-feira, e segurança removida não
   protege ninguém.

---

## O que ela faz

| A sua situação | O que você recebe |
|---|---|
| Uma ideia, nada construído ainda | Um plano de segurança antes da primeira linha de código: modelo de ameaça, decisão camada por camada e padrões seguros que viram a sua definição de pronto |
| Projeto já em andamento | O retrato de como está hoje, o que é crítico agora, e trilhos para que tudo daqui em diante saia certo por padrão |
| Uma feature ou um pull request | Resposta rápida: que camadas aquilo toca, que padrões se aplicam e o que precisa ser verdade antes de dar merge |
| Prestes a subir para produção | Um portão de pré-lançamento que trava a subida, cobrindo o que um atacante automatizado tenta primeiro |

Ela orienta todas as frentes: frontend, backend, dados, identidade, infraestrutura, borda,
observabilidade, pipeline, segredos, dependências, exposição pública, privacidade e pagamentos.

---

## Como ela pensa

**Dois adversários, e sempre os dois.** O **oportunista automatizado** é o escâner em massa, a
botnet e a ferramenta alugada, varrendo a internet atrás do que estiver fácil: dependência
desatualizada, `.env` exposto, cadastro público aberto, painel de admin com senha padrão. Um
endereço que acabou de entrar no ar costuma receber a primeira varredura em minutos, então a defesa
contra ele precisa ser **estrutural**: tem que valer sozinha, sem depender de ninguém lembrar de
nada. O **adversário motivado** estuda o seu sistema em específico, encadeia fraquezas pequenas até
virar uma grande e tem tempo de sobra. É ele que define menor privilégio, raio de estouro,
isolamento, detecção e recuperação. Na prática, a esmagadora maioria do que acontece é do primeiro
tipo, e ainda assim você precisa cobrir os dois. O tratamento completo está em
`references/threat-model.md`.

**Cinco padrões, conferidos em toda feature.** Regra de acesso ao dado negando por padrão e com
escopo por dono desde o instante em que a tabela nasce. Autorização decidida no servidor, nunca lida
de volta do cliente. Propriedade conferida objeto por objeto, inclusive nas chaves estrangeiras que
cruzam a fronteira entre clientes. Segredo só do lado do servidor, fora do pacote que vai para o
navegador e fora do histórico do Git. Toda entrada tratada como hostil, com upload validado pelo
conteúdo de verdade, e não pelo `Content-Type` ou pela extensão que o cliente mandou. Mais a
pergunta da cota: **o que impede isso de ser chamado um milhão de vezes?** Estourar uma cota paga é
uma negação de serviço que chega em forma de fatura. Cada padrão, com a versão segura e a versão
furada lado a lado, está em `references/app-defaults.md`.

---

## A regra da fricção

Todo controle é classificado pelo que custa às pessoas envolvidas. Vale o nível mais barato que
fecha o risco.

| Nível | Quem sente, e exemplos | Postura |
|---|---|---|
| 1. Invisível | Ninguém sente: regra que nega por padrão, autorização no servidor, consulta com escopo, `Content-Security-Policy` e `Strict-Transport-Security`, token de vida curta | Use à vontade |
| 2. Uma vez só | Uma pessoa sente, uma vez: TOTP ou WebAuthn nas contas de admin, chave SSH no lugar de senha, proteção de branch | Use em tudo que tenha poder administrativo |
| 3. Ocasional | Só em ação rara: confirmação extra antes de operação destrutiva ou de valor alto | Use com bisturi |
| 4. Constante | Toda interação: desafio em todo formulário, limite agressivo na navegação comum | Último recurso, e a proposta tem que listar as alternativas descartadas |

A experiência que vocês projetaram, para o admin, para quem desenvolve e para o usuário final, entra
como requisito. O `SKILL.md` e o `references/layer-playbooks.md` têm a classificação normativa e a
aplicam camada por camada.

---

## Instalação

Copie este diretório para a pasta de skills do seu agente:

```
~/.claude/skills/security-engineer/          # Claude Code
~/.agents/skills/security-engineer/          # local multi-runtime
.claude/skills/security-engineer/            # só um projeto
```

Depois abra uma sessão nova. A instalação é essa.

---

## Como usar

**Ela se chama sozinha** quando você começa um projeto, escolhe stack ou hospedagem, ou adiciona
login, pagamento, upload de arquivo, tabela no banco, área administrativa ou pipeline de deploy.

**Ou chame na mão:**

```
/security-engineer
/security-engineer planeja a segurança de um SaaS de agendamento em serverless com banco gerenciado
/security-engineer revisa essa feature antes de eu dar merge
/security-engineer a gente sobe sexta, roda o portão de pré-lançamento
```

**Ela responde no seu idioma.** O material é escrito em inglês para poder ser mantido e usado no
mundo todo. A conversa acontece no idioma em que você escrever, e ela respeita as convenções do seu
projeto quando encontra alguma.

**Ela lê antes de opinar.** Seus manifestos, sua configuração de infraestrutura, seu schema, as
instruções do projeto e o acesso a provedor que a sessão já tiver. Conselho que ignora a sua stack
real é ruído, então ela descobre primeiro e só pergunta o que não conseguiu achar sozinha, uma
pergunta por vez e em linguagem simples, com os acessos de que precisa reunidos num pedido único,
para você liberar tudo de uma vez.

---

## Explicação que serve para alguma coisa

Toda recomendação chega primeiro em português claro: o que é, por que importa, o que pode acontecer
de verdade e o que fazer. A parte técnica fica logo abaixo, pronta para quando você quiser.

> **Qualquer um troca o número e lê a ficha do vizinho.**
> Cada cliente tem uma ficha com um número. Seu sistema entrega a ficha para quem pedir aquele
> número, sem conferir de quem ela é. Aí alguém escreve um programinha que conta 1, 2, 3, 4 e baixa
> a ficha de todos os seus clientes.
> **Conserto:** antes de entregar a ficha, conferir se ela é de quem está pedindo.

Pergunte o porquê e você recebe o mecanismo, a especificação, o modo de falha e o trade-off, na
profundidade que quiser. Falar simples não é falar raso.

---

## O que vem junto

```
SKILL.md                            As instruções de operação
references/
  threat-model.md                   Os dois adversários, e o que cada um exige do projeto
  layer-playbooks.md                Treze camadas: decisões, controles, checagens, fricção
  app-defaults.md                   Os cinco padrões, com a versão segura e a versão furada
  change-review.md                  Revisar um diff: o que ele esconde e a régua de cada achado
  stack-profiles.md                 O que muda de serverless a servidor próprio e ferramenta local
  verification.md                   Como provar que cada controle vale, e o ferramental de scanner
  live-surfaces.md                  Conferir e mudar a config real, provedor por provedor
  operating-discipline.md           Idioma, consentimento, divulgação e o que nunca vai a público
  ai-surface.md                     Camada condicional: recurso de IA e agente, prompt injection
templates/
  security-plan.md                  O entregável
  pre-launch-checklist.md           O portão que trava a subida
  threat-model.md                   Uma página, porque modelo que ninguém lê não protege nada
assets/                             Artefatos para copiar, leia antes de rodar
  rls-multitenant.sql               Isolamento entre clientes: row security forçada, chave composta
  security-headers.md               Valores de cabeçalho, com trechos para proxy e middleware
  ci-security.yml                   Pipeline: varredura de segredo, de dependência e estática
  probe.sh                          Sonda externa de pré-lançamento, só leitura
  tenancy.test.example.ts           Os testes que provam o isolamento entre clientes
evals/                              Como este pacote é testado, veja abaixo
  validate.py                       Integridade do pacote, sem precisar de modelo
  run.py                            Quatorze pares de arquivo, pontuados por um agente
  cases/                            Um defeito plantado por camada, e o gêmeo consertado
```

---

## Como este pacote é testado

Orientação que nunca foi testada é opinião bem diagramada. Esta vem com o
ferramental que testa ela, e esse ferramental roda na sua máquina, não na
palavra de ninguém.

**Cada caso é um par.** Um arquivo com um defeito plantado, e o mesmo arquivo com
aquele defeito consertado. O agente revisa os dois sem saber qual é qual.

| Variante | Resultado exigido | O que isso prova |
|---|---|---|
| `vulnerable/` | o defeito aparece no relatório | a checagem pega o que ela existe para pegar |
| `fixed/` | o defeito não aparece | a checagem também sabe ficar quieta |

A segunda metade é o que importa. Checagem que dispara em tudo não é checagem, é
alarme emperrado, e ela passa em qualquer bateria que só dê defeito para ela
comer.

É um caso por camada, quatorze no total: tabela criada sem row security, registro
buscado sem condição de dono, token lido sem conferir assinatura, container
rodando como root com credencial cozida numa camada da imagem, pipeline
compilando código de estranho com os segredos do repositório à mão, chave
privilegiada exportada para o bundle do navegador, webhook sem assinatura
liberando plano pago, conteúdo de página não confiável chegando numa ferramenta
de banco. Camada sem caso reprova no validador, pela mesma razão que a skill
recusa matriz de cobertura com célula em branco.

```
python evals/validate.py            # selo de versão, READMEs espelhados, links, cobertura
python evals/run.py --self-test     # prova que o placar sabe reprovar, não chama nada
python evals/run.py                 # a bateria inteira, 28 chamadas de modelo
python evals/run.py --arm baseline  # a mesma revisão sem a skill carregada
```

O `validate.py` só precisa de Python. O `run.py` precisa da ferramenta de linha
de comando `claude`, que você já tem, e de nenhuma chave de API.

A mesma ideia está escrita no método, como controle negativo em
`references/verification.md`: antes de dar uma checagem por aprovada, quebre o
controle de propósito uma vez e veja a checagem ficar vermelha. É nesse minuto
que se descobre que a checagem apontava para um mock, para o estado atual em vez
do histórico, ou para uma lista de rotas que parou de ser atualizada.

**O que ela não é:** placar. Rode o braço baseline e um modelo bom pega quase
todos esses defeitos sozinho, e isso é o resultado esperado, porque defeito
plantado em arquivo de trinta linhas é a parte fácil do serviço. O que a skill
acrescenta é a passada que visita a camada de que ninguém lembra, a configuração
viva que ninguém leu, e a conta de quanto cada controle custa para quem usa o
produto. Nada disso cabe num arquivo só. O `evals/README.md` diz o resto do que
a bateria **não** prova, e vale ler antes de citar qualquer resultado.

---

## Mapeamento com o OWASP

Peça rastreabilidade e a skill busca o **OWASP Top 10** e o **OWASP API Security Top 10** na versão
atual, encaixa os achados e as decisões de camada nos identificadores de categoria daquela revisão,
e diz qual revisão e qual ano ela usou.

Buscar faz diferença. Essas listas são revisadas a cada poucos anos, categoria é fundida, renomeada
e renumerada, e um modelo recitando de memória arquiva os seus achados em identificadores que já não
significam o que ele pensa. Sem acesso à rede, ela diz qual revisão usou de memória e avisa que não
foi verificada.

Esse mapeamento é todo o trabalho de padrão que ela faz. Não é produto de conformidade e não emite
certificação nenhuma. Quando chegar questionário de cliente, o que você entrega é a matriz de
cobertura e a evidência das checagens de aceite, escritas no vocabulário do questionário.

---

## O que ela não faz

- Escrever o seu registro de lacunas em repositório público. A lista do que ainda não está protegido
  é um plano de ataque priorizado, escrito pelo próprio defensor. Ela fica com o time.
- Anunciar fraqueza em mensagem de commit. Commit descreve o que o código faz agora.
- Mudar qualquer coisa sem o seu aval naquela mudança específica, nem mexer em ambiente no ar para
  provar um ponto.
- Furar desafio de autenticação, segundo fator ou limite de requisição, inclusive os seus.
- Rodar varredura intrusiva contra sistema compartilhado ou de produção sem autorização explícita.
- Insistir depois que você decidiu com as cartas na mesa. O trade-off fica registrado com dono e
  gatilho de revisão, e o trabalho continua.

---

## O escopo, sem rodeio

Isto é engenharia de segurança para software em projeto e em construção, e ela é muito boa nisso.
Raciocina em cima do seu código, da sua configuração e da sua arquitetura, e acerta as decisões de
segurança enquanto elas ainda são decisões.

Ela não verifica o que não alcança. O que ficar fora do alcance é marcado para verificação manual,
em vez de ser dado como certo no silêncio.

---

## Reporte e versões

Achou problema na própria skill? Instrução insegura, padrão fraco, checagem de aceite que passa
quando deveria falhar?
**[Reporte em canal privado](https://github.com/bruno-org/security-engineer/security/advisories/new).**
O `SECURITY.md` tem o processo e o que está no escopo.

Se o que você achou não é problema de segurança, [abra uma
issue](https://github.com/bruno-org/security-engineer/issues/new).

A versão fica no campo `version` do `SKILL.md`, e o `CHANGELOG.md` registra o que mudou em cada uma.
Orientação de segurança envelhece: algoritmo é descontinuado, padrão é superado, recurso de provedor
muda de lugar. Confira o changelog antes de confiar numa cópia que já está parada faz tempo.

---

<div align="center">

Feito por **Bruno Henrique Leal da Cunha**
Licença [MIT](LICENSE)

</div>
