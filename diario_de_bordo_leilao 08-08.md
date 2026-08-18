# Diário de bordo — Projeto BD Leilão (Normalização)

---

# DIA 1

**Data:** 13 e 14/07/2026
**Objetivo do dia:** Migrar os dados da tabela única de importação (`leilao_bruto`) para o modelo relacional normalizado (11 tabelas), seguindo o modelo conceitual definido previamente.

---

## 1. Contexto inicial

- Os dados do leilão haviam sido importados em bloco para uma única tabela (`leilao_bruto`), servindo como *staging table*.
- O modelo conceitual (11 entidades) já existia, desenhado previamente em diagrama ER.
- Cada linha do `leilao_bruto` representa **um lote específico de um leilão** (uma tentativa de venda). Um mesmo bem físico pode voltar a leilão em outro processo/praça, e nesse caso gera uma **nova linha com ID próprio** — não é o mesmo registro.

## 2. Decisão estratégica: recomeçar a estrutura

Ao tentar popular `arrematante` com `ALTER TABLE ... AUTO_INCREMENT`, surgiu o erro **1833** (coluna usada em FK de `lote`). Decisão tomada: **apagar toda a estrutura de tabelas (mantendo só `leilao_bruto`) e recriar do zero**, seguindo uma ordem correta que evita esse tipo de trava.

### Ordem definida (metodologia adotada para o dia todo):
1. Mapear entidades independentes ("pai") e dependentes ("filhas")
2. Criar todas as tabelas **sem FOREIGN KEY**
3. Popular as tabelas "pai" primeiro
4. Popular as tabelas "filhas" com `INSERT ... SELECT` + `JOIN` para buscar os IDs já gerados
5. Adicionar as `FOREIGN KEY` somente no final
6. Validar (checar registros órfãos)

## 3. Entidades mapeadas (a partir do diagrama)

| Nível | Tabelas | Depende de |
|---|---|---|
| 1 | comercial, localizacao, juiz, diretor_cartorio, praca, leiloeiro, arrematante | — |
| 2 | lote | arrematante |
| 2 | cartorio | comercial, localizacao, juiz, diretor_cartorio |
| 3 | processo | cartorio |
| 4 | leilao | processo, praca, leiloeiro, lote |

## 4. Problemas encontrados e soluções aplicadas

Esses foram os principais obstáculos técnicos do dia, e viraram um padrão recorrente de solução:

| Problema | Causa | Solução |
|---|---|---|
| Campos "vazios" apareciam como `'0'` | Importação de CSV converteu vazio → `'0'` (string) | Filtro `WHERE coluna <> '0'` (confirmado tipo `VARCHAR` via `SHOW COLUMNS`) |
| Erro ao alterar `id_arrematante` para AUTO_INCREMENT | Coluna já usada em FK (`fk_lote_arrematante`) | Resolvido definitivamente ao recriar a estrutura sem FK prévia |
| `endereco` não aceita NULL | Coluna definida como NOT NULL | Placeholder `'A definir'`, a substituir depois por dados fictícios |
| Datas em formato brasileiro (`dd/mm/aaaa`) | Texto importado do CSV | `STR_TO_DATE(coluna, '%d/%m/%Y')` |
| Erro de truncamento em `percentual_comissao` | Valores armazenados como texto com `%` (ex: `'5%'`) | `CAST(REPLACE(coluna, '%', '') AS DECIMAL(5,2))` |
| Erro de truncamento em `comissao_leiloeiro` e `Valor_Inicial` | Separador decimal em vírgula (`,`) em vez de ponto | `CAST(REPLACE(coluna, ',', '.') AS DECIMAL(10,2))` |
| Duplicidade ao popular `lote` via `JOIN` (sublote+categoria+valor não únicos) | Chave descritiva não era exclusiva | Adicionada coluna `item_id_origem` (a partir de `Item_ID`, único confirmado) e repopulado usando essa chave |
| Duplicidade em `praca` (data+data+dia_semana) | Faltava capturar o número da praça | Adicionada coluna `numero_praca` (a partir da coluna `Praca` do bruto) |
| Duplicidade em `processo` (tipo_acao+reu+autor) | Chave descritiva não exclusiva | Adicionada coluna `numero_processo_origem` (a partir da coluna `Processo`) |
| INSERT de `leilao` gerou 80.659 linhas (esperado: 35.298) | `JOIN` com `praca` não incluía `dia_semana`, casando com múltiplas linhas (7 variações por praça) | Adicionado `AND p.dia_semana = b.Dia_semana` ao critério de `JOIN` |
| Erro ao inserir `arrematante`: valor `'DDD'` na coluna `ddd` | Linha de cabeçalho vazou para os dados | Filtro `AND DDD_Arrematante REGEXP '^[0-9]+$'` |

### Padrão de aprendizado do dia
Sempre que uma tabela de destino não guardava uma referência ao identificador original do `leilao_bruto`, o `JOIN` de tabelas dependentes corria risco de ambiguidade (mais de uma linha "batendo" nos critérios descritivos). A solução consistente foi: **adicionar uma coluna extra na tabela de destino guardando o ID/número de origem** (`Item_ID`, `Praca`, `Processo`), e usar essa chave — não os campos descritivos — nos `JOIN`s seguintes.

## 5. Status final das tabelas (fim do Dia 1)

| Tabela | Registros | Observações |
|---|---|---|
| comercial | 48 | |
| localizacao | 48 | coluna `Rua` preenchida com placeholder |
| juiz | 240 | |
| diretor_cartorio | 240 | |
| leiloeiro | 15 | |
| praca | 11.981 | com coluna extra `numero_praca` |
| arrematante | 243 | coluna `endereco` com placeholder `'A definir'` |
| lote | 35.298 | com coluna extra `item_id_origem` |
| cartorio | 240 | confirmado no Dia 2 |
| processo | 9.882 | com coluna extra `numero_processo_origem` |
| leilao | 35.298 | bate com o total de linhas do `leilao_bruto` ✅ |

Todas as tabelas de nível 1 a 4 foram populadas e as chaves de `JOIN` validadas (testes de `GROUP BY ... HAVING COUNT(*) > 1` retornaram vazio em todos os casos, após ajustes).

## 6. Próximos passos definidos ao final do Dia 1

1. Confirmar `COUNT(*) FROM cartorio`
2. Validar cada relação (checar registros órfãos) antes de criar as constraints
3. Criar as 10 `FOREIGN KEY`
4. Validação final geral do modelo
5. Tratar os placeholders (`'A definir'` em `endereco` e `Rua`)

---

# DIA 2

**Data:** 20/07/2026
**Objetivo do dia:** Validar a integridade referencial, criar as `FOREIGN KEY`, alinhar a estratégia de endereços e preparar o terreno para as queries de relatório.

## 1. Validação de integridade (checagem de registros órfãos)

Antes de criar qualquer FK, foram rodadas 10 queries de validação — uma para cada relação prevista no modelo. O princípio usado: um `LEFT JOIN` entre tabela filha e tabela pai, filtrando `WHERE filha.fk IS NOT NULL AND pai.id IS NULL`. Se a coluna de FK tinha um valor preenchido mas o `JOIN` não encontrou correspondência, o resultado da tabela pai vem `NULL` — sinal de uma referência "fantasma" (órfã), que impediria a criação da constraint.

**Resultado: todas as 10 validações retornaram `0` órfãos.** Nenhum ajuste foi necessário.

## 2. Confirmação de `cartorio`

```sql
SELECT COUNT(*) FROM cartorio;  -- retornou 240
```

Valor idêntico a `juiz` e `diretor_cartorio` (240), reforçando a hipótese de relação praticamente 1:1 entre cartório, juiz e diretor nesse conjunto de dados.

## 3. Criação das 10 FOREIGN KEY

Todas criadas com sucesso, uma de cada vez (para isolar qualquer erro, caso ocorresse):

```sql
ALTER TABLE lote ADD CONSTRAINT fk_lote_arrematante
FOREIGN KEY (id_arrematante) REFERENCES arrematante(id_arrematante);

ALTER TABLE cartorio ADD CONSTRAINT fk_cartorio_juiz
FOREIGN KEY (id_Juiz) REFERENCES juiz(id_Juiz);

ALTER TABLE cartorio ADD CONSTRAINT fk_cartorio_localizacao
FOREIGN KEY (ID_local_cartorio) REFERENCES localizacao(ID_local_cartorio);

ALTER TABLE cartorio ADD CONSTRAINT fk_cartorio_diretor
FOREIGN KEY (id_diretor) REFERENCES diretor_cartorio(id_diretor);

ALTER TABLE cartorio ADD CONSTRAINT fk_cartorio_comercial
FOREIGN KEY (id_comercial) REFERENCES comercial(idComercial);

ALTER TABLE processo ADD CONSTRAINT fk_processo_cartorio
FOREIGN KEY (id_cartorio) REFERENCES cartorio(Id_cartorio);

ALTER TABLE leilao ADD CONSTRAINT fk_leilao_praca
FOREIGN KEY (Id_praca) REFERENCES praca(Id_praca);

ALTER TABLE leilao ADD CONSTRAINT fk_leilao_lote
FOREIGN KEY (id_lote) REFERENCES lote(id_lote);

ALTER TABLE leilao ADD CONSTRAINT fk_leilao_processo
FOREIGN KEY (id_processo) REFERENCES processo(id_processo);

ALTER TABLE leilao ADD CONSTRAINT fk_leilao_leiloeiro
FOREIGN KEY (id_leiloeiro) REFERENCES leiloeiro(id_leiloeiro);
```

**Status: as 10 constraints foram criadas com sucesso.** O modelo agora tem integridade referencial ativa — o banco passa a impedir inserções/exclusões que quebrem as relações entre as tabelas.

## 4. Discussão conceitual: `ON DELETE CASCADE`

Foi discutido se a decisão de usar (ou não) `ON DELETE CASCADE` nas FKs é responsabilidade de um profissional júnior. Conclusão: é geralmente uma **decisão de arquitetura/modelagem de dados**, tomada por quem desenha o schema (DBA, arquiteto, dev sênior/pleno), não algo esperado de quem está começando — pelo risco de exclusões em cascata não previstas e pela necessidade de conhecimento profundo da regra de negócio. Para o júnior, o relevante é **reconhecer que a opção existe** e saber identificar o comportamento (CASCADE, RESTRICT, SET NULL) quando encontrado em um projeto real. As FKs deste projeto foram criadas sem CASCADE (comportamento padrão, mais seguro).

## 5. Alinhamento da lógica de endereços

Ficou definido que:
- **`arrematante`, `cartorio` e `lote`** precisam ter endereço próprio (não pode ser NULL)
- **`localizacao`** é específica do `cartorio` — guarda dados amplos (Comarca, Estado, Região)
- O campo **`Rua`** dentro de `localizacao` é a normalização do endereço detalhado (logradouro, número, complemento — ex: `"Rua Antonio Vasques, 123, apartamento 13B"`), a ser expandido com mais colunas no futuro
- **Por ora**, o foco não é preencher os endereços com dados fictícios reais — isso fica para depois. A prioridade passa a ser **gerar queries de relatório**

### Ajuste de estrutura decorrente
A tabela `lote` não tinha coluna de endereço (esquecida na criação original). Adicionada:

```sql
ALTER TABLE lote ADD COLUMN endereco VARCHAR(255) NOT NULL DEFAULT 'A definir';
```

Usar `DEFAULT` garante que: (a) as 35.298 linhas já existentes recebem o placeholder automaticamente, e (b) qualquer `INSERT` futuro que não cite essa coluna explicitamente continua funcionando sem erro — desde que a query nomeie as colunas (não use `INSERT ... VALUES` posicional).

## 6. Status final das tabelas (fim do Dia 2)

| Tabela | Registros | Observações |
|---|---|---|
| comercial | 48 | |
| localizacao | 48 | `Rua` = placeholder (normalização do endereço detalhado do cartório) |
| juiz | 240 | |
| diretor_cartorio | 240 | |
| leiloeiro | 15 | |
| praca | 11.981 | |
| arrematante | 243 | `endereco` = placeholder |
| lote | 35.298 | `endereco` adicionada nesta sessão, com placeholder |
| cartorio | 240 | |
| processo | 9.882 | |
| leilao | 35.298 | |

**Todas as 10 FOREIGN KEY criadas e ativas.** Modelo relacional completo e íntegro.

## 7. Próximos passos (para retomar)

1. Gerar queries de relatório (foco atual) — ex: lotes por arrematante, arrecadação por leiloeiro/praça, taxa de sucesso de venda, lotes que foram a mais de uma praça, ranking de comarcas
2. Futuramente: preencher os placeholders de endereço (`arrematante`, `lote`, `localizacao.Rua`) com dados fictícios reais
3. Futuramente: expandir `localizacao` com mais campos de endereço, conforme necessidade

---

# DIA 3

**Data:** 21/07/2026
**Objetivo do dia:** Corrigir um bug identificado em `lote.id_arrematante` (todos os valores `NULL`) e retomar a construção de queries de relatório.

## 1. Problema identificado: `lote.id_arrematante` todo `NULL`

Ao revisar os dados, percebeu-se que **toda** a coluna `id_arrematante` em `lote` estava `NULL` — mesmo sabendo que deveria haver lotes vendidos com arrematante vinculado.

### Causa raiz
Um problema de **ordem de execução** no Dia 1: a tabela `lote` foi populada (19:02) usando um `LEFT JOIN` contra `arrematante` — mas a tabela `arrematante` só foi populada **depois** (19:32), quando percebemos que ela estava vazia. Ou seja, no momento do `INSERT` de `lote`, não existia nenhum registro em `arrematante` para casar — todo o `JOIN` retornou `NULL`, não porque os lotes não tinham comprador, mas porque a tabela de referência ainda não existia.

**Lição:** ao popular tabelas dependentes via `JOIN`, é essencial garantir que a tabela referenciada já esteja *completamente* populada antes — a ordem de execução importa tanto quanto a lógica da query em si.

## 2. Tentativa de correção via `UPDATE ... JOIN`

Query planejada para corrigir apenas a coluna `id_arrematante`, sem alterar o restante dos dados de `lote`, usando a chave forte já criada (`item_id_origem`):

```sql
UPDATE lote l
JOIN leilao_bruto b ON b.Item_ID = l.item_id_origem
LEFT JOIN arrematante a
    ON a.nome = b.Arrematante
    AND a.telefone = b.Telefone_Arrematante
    AND a.email = b.Email_Arrematante
SET l.id_arrematante = a.id_arrematante;
```

### Erro 1: Modo de atualização segura (Error Code 1175)
```
You are using safe update mode and you tried to update a table without a WHERE that uses a KEY column.
```
**Causa:** o MySQL Workbench bloqueia por padrão `UPDATE`/`DELETE` sem `WHERE` sobre coluna-chave, como proteção contra atualizações em massa acidentais.

**Solução aplicada:** adicionado um `WHERE` "cosmético" satisfazendo a exigência sem filtrar de fato:
```sql
WHERE l.id_lote > 0
```
(Alternativa possível, não usada: `SET SQL_SAFE_UPDATES = 0;` antes da query.)

### Erro 2: Timeout / queda de conexão por lentidão
Ao rodar o `UPDATE` corrigido, a query ficou em execução por mais de **20 minutos** (1.248 segundos) sem concluir, e a conexão do Workbench caiu visualmente (mesmo com o processo ainda ativo no servidor, verificado via `SHOW PROCESSLIST`).

**Causa:** ausência de índice nas colunas usadas nos critérios de `JOIN` (`lote.item_id_origem`, `leilao_bruto.Item_ID`, `arrematante.nome/telefone/email`). Sem índice, o MySQL faz uma varredura completa (*full table scan*) para cada combinação, o que é extremamente custoso numa tabela de 35 mil linhas.

**Processo de diagnóstico:**
1. `SHOW PROCESSLIST;` — usado para confirmar que a query ainda estava rodando no servidor (`State: executing`), mesmo com a interface do Workbench parecendo travada.
2. Acompanhamento do campo `Time` (segundos em execução) — confirmando que o processo avançava, mas de forma muito lenta.
3. Decisão de interromper após ~20 minutos sem sinal de conclusão: `KILL <Id_do_processo>;`
4. Confirmado que o `UPDATE` não havia sido aplicado (rollback automático do InnoDB ao matar o processo):
   ```sql
   SELECT COUNT(*) FROM lote WHERE id_arrematante IS NOT NULL;  -- retornou 0
   ```

## 3. Solução definitiva: criação de índices

```sql
ALTER TABLE lote ADD INDEX idx_item_id_origem (item_id_origem);
ALTER TABLE leilao_bruto ADD INDEX idx_item_id (Item_ID);
ALTER TABLE arrematante ADD INDEX idx_nome_tel_email (nome, telefone, email);
```

Após criar os índices, o mesmo `UPDATE` (idêntico ao que travou por 20+ minutos) rodou em **2,625 segundos**:

```sql
UPDATE lote l
JOIN leilao_bruto b ON b.Item_ID = l.item_id_origem
LEFT JOIN arrematante a
    ON a.nome = b.Arrematante
    AND a.telefone = b.Telefone_Arrematante
    AND a.email = b.Email_Arrematante
SET l.id_arrematante = a.id_arrematante
WHERE l.id_lote > 0;
```

**Resultado:** `Rows matched: 35298` / `Changed: 8780`

### Conceito-chave aprendido: por que índice acelera o JOIN
Sem índice, comparar colunas em um `JOIN` é O(n×m) — cada linha de uma tabela é comparada contra todas as linhas da outra. Um índice cria uma estrutura de busca (B-Tree, padrão no InnoDB) que permite "pular direto" ao valor procurado, em vez de varrer tudo — reduzindo drasticamente o tempo de execução em tabelas grandes. O custo do índice é espaço em disco e uma pequena penalidade em escritas (`INSERT`/`UPDATE`), por isso normalmente é aplicado *depois* da carga pesada de dados, e apenas nas colunas usadas com frequência em `JOIN`, `WHERE` e `ORDER BY`.

## 4. Validação final

```sql
SELECT COUNT(*) FROM lote WHERE id_arrematante IS NOT NULL;  -- 8.780 (lotes vendidos)
SELECT COUNT(*) FROM lote WHERE id_arrematante IS NULL;      -- 26.518 (lotes não vendidos)
```

Total: 8.780 + 26.518 = 35.298 ✅ bate com o total de `lote`. Em média, cada um dos 243 arrematantes comprou aproximadamente 36 lotes.

## 5. Retomada do trabalho de relatórios

Com o dado corrigido, o projeto retoma a etapa de tradução de perguntas de negócio em queries SQL (ver arquivo `perguntas_relatorio_powerbi.md`), começando pela:

> **Pergunta 1:** Quantos lotes cada arrematante comprou, do maior para o menor número de lotes?

---

# DIA 5

**Data:** 24/07/2026
**Objetivo do dia:** Iniciar a etapa de queries de relatório, começando pela Pergunta 1 do documento `perguntas_relatorio_powerbi.md`, e documentar o processo de validação de resultados em SQL.

## Pergunta 1

> Quantos lotes cada arrematante comprou, do maior para o menor número de lotes?

### 1. A query

```sql
SELECT
    a.id_arrematante,
    a.nome,
    COUNT(l.id_lote) AS qtd_lotes_comprados
FROM arrematante a
JOIN lote l ON l.id_arrematante = a.id_arrematante
GROUP BY a.id_arrematante, a.nome
ORDER BY qtd_lotes_comprados DESC;
```

**Explicação linha a linha:**

- **`JOIN` (não `LEFT JOIN`)** — usado propositalmente. Só interessa trazer arrematantes que **de fato** compraram algo; como a tabela `arrematante` só foi populada com quem realmente arrematou (filtro aplicado no Dia 1), não existe o risco de excluir ninguém indevidamente.
- **`COUNT(l.id_lote)`** — conta quantas linhas de `lote` cada arrematante tem vinculada. Contar pela chave da tabela (`id_lote`), em vez de `COUNT(*)`, é uma boa prática que deixa explícito o que está sendo contado.
- **`GROUP BY a.id_arrematante, a.nome`** — obrigatório em SQL: toda coluna no `SELECT` que não é uma agregação (`COUNT`, `SUM`, etc.) precisa aparecer no `GROUP BY`. Como `id_arrematante` já é único, `nome` "acompanha" sem gerar ambiguidade.
- **`ORDER BY qtd_lotes_comprados DESC`** — ordena do maior comprador para o menor.

### 2. Processo de validação do resultado

Ao rodar a query, o MySQL Workbench exibiu apenas uma parte do resultado (por volta de 50 linhas), o que inicialmente pareceu indicar que só uma fração dos 243 arrematantes cadastrados havia realizado compras.

**Passo de verificação aplicado:**

```sql
SELECT COUNT(*) FROM (
    SELECT a.id_arrematante
    FROM arrematante a
    JOIN lote l ON l.id_arrematante = a.id_arrematante
    GROUP BY a.id_arrematante
) AS sub;
```

Resultado: **243** — confirmando que todos os arrematantes cadastrados aparecem no resultado completo. O que havia sido visto antes era apenas o recorte de exibição padrão do client SQL (grid limitada a um número máximo de linhas), não uma limitação real dos dados.

**Segunda camada de validação**, feita para confirmar não só a quantidade de linhas, mas a **exatidão do valor** de um registro específico: o topo do ranking (`Renata Gouveia`, 55 lotes) foi conferido diretamente contra a fonte original, por dois caminhos:

```sql
SELECT COUNT(*)
FROM leilao_bruto
WHERE Arrematante = 'Renata Gouveia';
```

E também manualmente no arquivo `.csv` original que deu origem ao `leilao_bruto`. Ambas as conferências bateram exatamente em **55**, confirmando que:
- A correção de `lote.id_arrematante` feita no Dia 3 está correta
- A query de ranking está contando certo
- Não há perda de registros na cadeia de `JOIN`s

### 3. Insight de negócio obtido

O resultado revela a existência de **arrematantes recorrentes com volume de compra muito acima da média** — a média geral é de ~36 lotes por arrematante (8.780 lotes vendidos ÷ 243 arrematantes), mas o topo do ranking mostra vários nomes na faixa de 41 a 55 lotes, com destaque para:

| Posição | Arrematante | Lotes comprados |
|---|---|---|
| 1º | Renata Gouveia | 55 |
| 2º | Murilo Rangel | 53 |
| 3º | Mateus Guimarães | 51 |
| 3º | Mateus Loureiro | 51 |

Esse padrão sugere fortemente a presença de **compradores profissionais/investidores recorrentes** no conjunto de dados, em vez de apenas pessoas físicas comprando um bem isolado — respondendo diretamente a uma das perguntas de negócio levantadas na Seção 4 do documento `perguntas_relatorio_powerbi.md` ("Existem arrematantes recorrentes?").

## Lição metodológica registrada

> Ferramentas de client SQL (Workbench, DBeaver, etc.) servem para **desenvolver e validar a lógica** de uma query — não são o ambiente final de análise, pois costumam limitar a exibição de resultados grandes por padrão. Antes de tirar qualquer conclusão de negócio a partir de um resultado visualizado na tela, é necessário confirmar o total real de linhas (`COUNT`) e, quando possível, validar valores específicos contra a fonte original. Para análise/apresentação final, o caminho mais adequado é exportar o resultado (CSV/Excel) ou, idealmente, conectar a ferramenta de BI (Power BI) diretamente ao banco de dados — evitando o gargalo do limite de exibição do client SQL.

## Pergunta 2

> Qual o valor total gasto por cada arrematante, do maior para o menor?

### Query (desenvolvida pelo autor do projeto)

```sql
SELECT
    a.id_arrematante,
    a.nome,
    ROUND(SUM(l.valor_lance_final), 2) AS total_gasto
FROM arrematante a
JOIN lote l ON l.id_arrematante = a.id_arrematante
GROUP BY a.id_arrematante, a.nome
ORDER BY total_gasto DESC;
```

Mesma estrutura da Pergunta 1, trocando `COUNT(l.id_lote)` por `SUM(l.valor_lance_final)` — a métrica muda de "quantidade de lotes" para "valor monetário total pago". Aplicado `ROUND(..., 2)` para evitar imprecisões de ponto flutuante na soma de valores decimais.

### Validação
- Contagem de linhas do resultado: **243** ✅ (todos os arrematantes presentes)
- Valor do topo do ranking (`Mateus Loureiro`, R$ 23.705.895,95) conferido contra o `leilao_bruto`/CSV original: **bateu** ✅

### Insight
`Mateus Loureiro` era apenas o 2º colocado em **quantidade** de lotes (Pergunta 1), mas assume a 1ª posição em **valor total gasto** — indicando que ele compra lotes de maior valor médio que quem lidera em volume (`Renata Gouveia`). Essa observação motivou a Pergunta 3 (ticket médio), para diferenciar formalmente os perfis de "compra em volume" vs. "compra de alto valor".

## Pergunta 3

> Qual o ticket médio (valor médio gasto por lote) de cada arrematante, do maior para o menor?

### Query (desenvolvida pelo autor do projeto)

```sql
SELECT
    a.id_arrematante,
    a.nome,
    ROUND(AVG(l.valor_lance_final), 2) AS ticket_medio
FROM arrematante a
JOIN lote l ON l.id_arrematante = a.id_arrematante
GROUP BY a.id_arrematante, a.nome
ORDER BY ticket_medio DESC;
```

Mesma estrutura das anteriores, agora usando `AVG()` — que calcula a média diretamente, sem necessidade de dividir `SUM` por `COUNT` manualmente.

### Validação
- Contagem de linhas do resultado: **243** ✅
- Valor do topo do ranking conferido contra o `leilao_bruto`: **bateu** ✅

### Insight
O ranking de ticket médio é **completamente diferente** dos rankings das Perguntas 1 e 2 — o topo passa a ser `Douglas Amorim` (R$ 581.194,74 de ticket médio), que não aparecia entre os líderes de quantidade nem de valor total. Isso confirma a existência de **pelo menos três perfis distintos de arrematante**:

| Perfil | Característica | Exemplo |
|---|---|---|
| Alto volume | Muitos lotes, ticket médio moderado | Renata Gouveia (55 lotes) |
| Alto valor agregado | Volume + valor combinados geram o maior total gasto | Mateus Loureiro |
| Alto ticket unitário | Poucos lotes, mas de valor unitário muito elevado | Douglas Amorim |

Essa segmentação é um resultado valioso para o relatório de Power BI — permite construir uma matriz/segmentação de arrematantes por perfil de investimento, em vez de um único ranking simplista.

---

# DIA 6

**Data:** 25/07/2026
**Objetivo do dia:** Avançar nas perguntas de negócio dos Blocos 2 (precificação) e 3 (leiloeiros), documentar uma correção conceitual importante (ágio vs. deságio) e registrar uma lacuna do modelo de dados identificada durante a análise.

## Pergunta 4 (Bloco 2)

> Qual o deságio médio entre o valor inicial e o valor final de venda dos lotes?

### Primeira tentativa e correção de sintaxe/lógica
A primeira versão da query continha erro de sintaxe (parênteses desencontrados no `ROUND`) e um `GROUP BY` desnecessário/inválido (agrupando por um alias inexistente na tabela). Corrigido para uma agregação simples, sem `GROUP BY`, já que o objetivo era um único valor consolidado.

### Correção conceitual: "deságio" não se aplicava
Ao calcular `(valor_inicial - valor_lance_final) / valor_inicial`, o resultado veio **negativo** (-71,3%), o que não fazia sentido para "deságio" (desvalorização). Foi identificado que, em leilão, `valor_inicial` representa apenas o **lance mínimo de abertura da disputa**, não um valor de mercado/avaliação do bem — e o valor final tende a ser **maior**, por conta da disputa entre arrematantes (ágio, não deságio). A fórmula foi invertida para refletir corretamente esse comportamento:

```sql
SELECT
    ROUND(
        AVG((l.valor_lance_final - l.valor_inicial) / l.valor_inicial) * 100,
        2
    ) AS agio_medio_percentual
FROM lote l
WHERE l.id_arrematante IS NOT NULL;
```

### Correção de filtro: `valor_lance_final IS NOT NULL` ≠ "vendido"
Mesmo após a correção conceitual, o resultado ainda veio negativo (-71,3%). Investigação revelou que `valor_lance_final` está preenchido em **todos os 35.298 lotes** (vendidos ou não) — representando "maior lance recebido", mesmo quando insuficiente para efetivar a venda. Apenas **8.780** lotes têm de fato `id_arrematante` preenchido (critério correto de "venda concluída", definido no Dia 3). Após ajustar o filtro para `WHERE id_arrematante IS NOT NULL`, o resultado passou a fazer sentido:

**Resultado final: ágio médio de 15,01%** sobre o lance mínimo, nos lotes efetivamente vendidos.

### Insight
O ágio de 15% confirma que existe disputa real entre arrematantes na maioria das vendas concluídas. Entretanto, como `valor_inicial` não é uma avaliação de mercado, esse percentual **não mede quanto o comprador pagou acima do valor real do bem** — apenas a valorização dentro da disputa daquela praça específica.

### Lacuna de modelo identificada → nova pergunta registrada
Foi observado que o modelo de dados não possui uma coluna de "valor de avaliação" do bem. O `valor_inicial` pode, inclusive, já representar um valor com desconto em praças subsequentes (2ª, 3ª...), caso o lote não tenha tido licitantes na tentativa anterior. Isso motivou a inclusão de uma nova pergunta no documento `perguntas_relatorio_powerbi.md` (Bloco 2):

> **Qual o deságio real entre praças, para o mesmo lote físico?** Requer comparar o `valor_inicial` do mesmo bem entre praças diferentes (não a mesma linha de `lote`) — ainda pendente de resolução, pois demanda identificar linhas de `lote` que representam o mesmo bem físico em tentativas distintas (possivelmente via `Processo + SubLote + Categoria`).

## Pergunta 5 (Bloco 2)

> Existe correlação entre a categoria do lote e a taxa de venda?

Simplificada para: qual o percentual de lotes vendidos em relação ao total ofertado, por categoria.

```sql
SELECT
    categoria,
    COUNT(*) AS total_ofertado,
    SUM(CASE WHEN id_arrematante IS NOT NULL THEN 1 ELSE 0 END) AS total_vendido,
    ROUND(
        SUM(CASE WHEN id_arrematante IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) * 100,
        2
    ) AS taxa_venda_percentual
FROM lote
GROUP BY categoria
ORDER BY taxa_venda_percentual DESC;
```

**Técnica destacada:** uso de `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` para obter uma contagem condicional (vendidos) na mesma passada em que se conta o total — evitando subconsultas ou múltiplas queries.

### Resultado

| Categoria | Total ofertado | Total vendido | Taxa de venda |
|---|---|---|---|
| Móveis | 11.339 | 2.829 | 24,95% |
| Automóveis | 11.087 | 2.757 | 24,87% |
| Imóveis | 12.872 | 3.194 | 24,81% |

Validado: soma de ofertados (35.298) e vendidos (8.780) por categoria bateu com os totais gerais já confirmados anteriormente.

### Insight
**Não há diferença relevante na taxa de venda entre categorias** (variação menor que 0,15 pontos percentuais) — contrariando a hipótese intuitiva de que bens mais complexos/caros (imóveis) venderiam proporcionalmente menos que bens mais líquidos (automóveis, móveis). A taxa geral de conversão do leilão gira em torno de **~25%** (1 em cada 4 lotes ofertados é arrematado), parecendo ser uma característica estrutural do mercado, não relacionada ao tipo de bem.

## Pendências para retomar

- Pergunta do Bloco 2: lotes com maior valor inicial demoram mais ou menos para vender?
- Bloco 3 completo: performance de leiloeiros (taxa de conversão, ranking por valor arrecadado/comissão)
- Nova pergunta de deságio real entre praças (Bloco 2), registrada mas ainda não respondida

---

# DIA 7

**Data:** 26/07/2026
**Objetivo do dia:** Concluir o Bloco 2 (precificação/mercado) e avançar no Bloco 3 (performance de leiloeiros).

## Pergunta 6 (Bloco 2 — última do bloco)

> Lotes com maior valor inicial demoram mais para vender, ou o contrário?

### Esclarecimento conceitual sobre as datas
Antes de montar a query, foi alinhado o significado das colunas de data em `praca`: `data_abertura` é apenas informativa (vem do edital), enquanto `data_fechamento` representa o encerramento daquela praça — logo, **se o lote foi vendido, `data_fechamento` é a data da venda**.

### Reformulação da pergunta
Como ainda não existe uma forma de ligar múltiplas linhas de `lote` que representam o mesmo bem físico em praças diferentes (limitação já registrada no Dia 6), a pergunta foi resolvida usando o **número da praça em que a venda ocorreu** como proxy de "dificuldade/tempo para vender" (quanto maior o número da praça, mais tentativas foram necessárias).

```sql
SELECT
    CASE
        WHEN l.valor_inicial < 50000 THEN 'Baixo (< 50k)'
        WHEN l.valor_inicial BETWEEN 50000 AND 200000 THEN 'Médio (50k-200k)'
        ELSE 'Alto (> 200k)'
    END AS faixa_valor_inicial,
    COUNT(*) AS qtd_lotes_vendidos,
    ROUND(AVG(p.numero_praca), 2) AS media_numero_praca
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN praca p ON p.Id_praca = le.Id_praca
WHERE l.id_arrematante IS NOT NULL
GROUP BY faixa_valor_inicial
ORDER BY media_numero_praca DESC;
```

### Resultado

| Faixa | Qtd. vendidos | Praça média |
|---|---|---|
| Baixo (< 50k) | 2.049 | 1,51 |
| Médio (50k-200k) | 3.456 | 1,45 |
| Alto (> 200k) | 3.275 | 1,42 |

*Valores atualizados em 31/07/2026 (ver Dia 10), após a correção da numeração de praça aplicada no Dia 9. Resultado original (antes da correção): Baixo 1,60 / Médio 1,55 / Alto 1,52.*

### Insight

Existe uma leve tendência: quanto maior o valor inicial, menor o número médio de praças necessárias para vender.

Ou seja, lotes de menor valor demoram (ligeiramente) mais para vender que lotes de maior valor — o oposto do que a intuição comum sugeriria ("bens caros são mais difíceis de vender").

**Possível explicação (hipótese, não comprovada pelos dados):** bens de maior valor inicial tendem a ser imóveis maiores/melhores localizados ou veículos de padrão superior, que podem atrair investidores profissionais com mais poder de compra (lembra dos "grandes arrematantes" identificados no Bloco 4) — enquanto bens de menor valor podem ser itens de nicho mais restrito, com menos gente disposta a competir por eles logo na 1ª tentativa.

**Ressalva importante sobre o tamanho do efeito:** a diferença entre as faixas é pequena (0,09 no intervalo de 1,42 a 1,51) — não é um efeito dramático. Vale reportar isso com cautela no relatório: existe uma tendência, mas é sutil, não uma regra forte.

**Nota de revisão (Dia 10):** após a correção da numeração de praça (Dia 9), todas as faixas caíram de forma proporcional (~0,09 a 0,10 cada), sem alterar a direção nem a magnitude relativa da tendência — a conclusão de negócio permanece a mesma, apenas com valores absolutos mais baixos e corretos.

**Bloco 2 (precificação/mercado) concluído**, restando apenas a pergunta pendente de deságio real entre praças, registrada no Dia 6 (depende de resolver a identificação do mesmo bem físico entre linhas de `lote`).

## Pergunta 7 (Bloco 3)

> Qual leiloeiro tem a melhor taxa de conversão (lotes vendidos ÷ lotes ofertados)?

```sql
SELECT
    le_o.id_leiloeiro,
    le_o.nome,
    COUNT(*) AS total_ofertado,
    SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) AS total_vendido,
    ROUND(
        SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) * 100,
        2
    ) AS taxa_conversao_percentual
FROM leilao le
JOIN lote l ON l.id_lote = le.id_lote
JOIN leiloeiro le_o ON le_o.id_leiloeiro = le.id_leiloeiro
GROUP BY le_o.id_leiloeiro, le_o.nome
ORDER BY taxa_conversao_percentual DESC;
```

**Observação técnica:** a query parte de `leilao` (não de `lote`), pois `id_leiloeiro` só existe nessa tabela. Validado que `COUNT(*)` a partir de `leilao` equivale à contagem a partir de `lote`, por conta da relação 1:1 confirmada entre as duas tabelas.

### Validação
Soma de todos os leiloeiros comparada com os totais gerais já conhecidos (35.298 ofertados / 8.780 vendidos): **bateu exatamente** ✅

### Resultado (15 leiloeiros)

| Posição | Leiloeiro | Taxa de conversão |
|---|---|---|
| 1º | Dalva | 26,44% |
| 2º | Renan | 25,98% |
| 3º | Jerônimo | 25,86% |
| ... | ... | ... |
| 14º | Paula | 24,03% |
| 15º | Márcia | 23,75% |

### Insight
Diferença de **2,69 pontos percentuais** entre o melhor e o pior leiloeiro — um intervalo mais expressivo que o observado entre categorias de lote (Pergunta 5, variação < 0,15 p.p.). Isso sugere que o leiloeiro responsável pode, de fato, influenciar a taxa de sucesso de venda.

**Ressalva:** o volume de lotes ofertados varia muito entre leiloeiros (de 720 a 4.416). Leiloeiros com menor volume (`Renan`, `Genivaldo`) têm taxas mais sujeitas à variação estatística — ressalva importante para o relatório final.

## Pergunta 8 (Bloco 3 — última do bloco)

> Ranking de leiloeiros por valor total arrecadado e por comissão gerada.

```sql
SELECT
    le_o.id_leiloeiro,
    le_o.nome,
    ROUND(SUM(l.valor_lance_final), 2) AS valor_total_arrecadado,
    ROUND(SUM(l.comissao_leiloeiro), 2) AS comissao_total_gerada
FROM leilao le
JOIN lote l ON l.id_lote = le.id_lote
JOIN leiloeiro le_o ON le_o.id_leiloeiro = le.id_leiloeiro
WHERE l.id_arrematante IS NOT NULL
GROUP BY le_o.id_leiloeiro, le_o.nome
ORDER BY valor_total_arrecadado DESC;
```

**Ponto de atenção reforçado:** o filtro `WHERE l.id_arrematante IS NOT NULL` é essencial — sem ele, os valores de `valor_lance_final` e `comissao_leiloeiro` de lotes não vendidos inflariam indevidamente os totais (mesma lição já registrada na Pergunta 4).

### Validação
Comparada a soma agrupada por leiloeiro contra a soma direta em `lote` (sem `JOIN`):

| | Via leiloeiro (agrupado) | Direto em `lote` |
|---|---|---|
| Valor total arrecadado | R$ 3.087.769.016,23 | R$ 3.087.769.016,23 |
| Comissão total | R$ 149.568.522,30 | R$ 149.568.522,30 |

### Resultado (15 leiloeiros, ordenado por valor arrecadado)

| Posição | Leiloeiro | Valor arrecadado | Comissão gerada |
|---|---|---|---|
| 1º | Antonio | R$ 359.838.540,90 | R$ 17.543.435,13 |
| 2º | Márcia | R$ 304.213.952,61 | R$ 14.825.601,21 |
| 3º | Elizabete | R$ 278.670.939,60 | R$ 13.462.795,63 |
| 4º | Valério | R$ 273.478.393,07 | R$ 13.233.119,18 |
| 5º | Pedro | R$ 270.399.312,69 | R$ 13.042.652,23 |
| 6º | Paula | R$ 266.765.962,96 | R$ 12.847.984,94 |
| 7º | Mónica | R$ 212.826.231,37 | R$ 10.222.136,39 |
| 8º | Dalva | R$ 190.948.893,77 | R$ 9.209.870,85 |
| 9º | Marcelino | R$ 187.922.242,27 | R$ 9.150.383,76 |
| 10º | José | R$ 187.020.951,26 | R$ 9.099.560,77 |
| 11º | Jerônimo | R$ 186.526.983,64 | R$ 9.010.580,44 |
| 12º | Ramon | R$ 173.418.995,92 | R$ 8.404.640,15 |
| 13º | Genivaldo | R$ 71.090.713,46 | R$ 3.447.469,06 |
| 14º | Renan | R$ 67.227.794,48 | R$ 3.287.752,97 |
| 15º | Gilberto | R$ 57.419.108,24 | R$ 2.780.539,60 |

### Insight

**Antonio lidera com folga** em valor arrecadado (R$ 359,8 milhões) e comissão (R$ 17,5 milhões), à frente do 2º colocado por uma margem considerável.

**Achado principal — cruzamento com a Pergunta 7:** existe uma **inversão notável** entre eficiência (taxa de conversão) e volume de negócios. `Dalva`, líder em taxa de conversão (26,44% — Pergunta 7), aparece apenas em **8º lugar** em valor arrecadado. Já `Antonio`, com taxa de conversão apenas mediana (24,41%, 11º lugar — Pergunta 7), lidera disparado em valor absoluto — explicado principalmente pelo seu maior volume de lotes ofertados (4.416, quase o dobro de vários concorrentes). **Conclusão: "eficiência proporcional" e "volume de negócios" são métricas independentes** — vale apresentar as duas lado a lado no relatório, evitando a leitura simplista de "melhor leiloeiro" com base em uma métrica isolada.

**Achado secundário:** a comissão se mantém como uma fração praticamente constante do valor arrecadado em todos os leiloeiros (~4,8% a 4,9%), sugerindo uma taxa de comissão padronizada no mercado, não negociada individualmente.

**Bloco 3 (performance de leiloeiros) concluído.**

## Pendências para retomar

- Bloco 4 (parcialmente feito — falta a pergunta de concentração/Pareto entre arrematantes)
- Blocos 5 (geografia) e 6 (sazonalidade), ainda não iniciados
- Pergunta pendente de deságio real entre praças (Bloco 2)

---

# DIA 8

**Data:** 27/07/2026
**Objetivo do dia:** Concluir o Bloco 4 (comportamento do arrematante) e percorrer integralmente os Blocos 1 (eficiência judicial), 5 (geografia) e 6 (sazonalidade).

## Pergunta 9 (Bloco 4 — última do bloco)

> Qual a concentração do valor total arrematado entre os arrematantes (lógica de Pareto)?

Resolvida em duas etapas complementares:

**Versão simplificada (com `LIMIT`):**
```sql
SELECT
    (SELECT ROUND(SUM(valor_top), 2)
     FROM (
         SELECT SUM(l.valor_lance_final) AS valor_top
         FROM arrematante a
         JOIN lote l ON l.id_arrematante = a.id_arrematante
         GROUP BY a.id_arrematante
         ORDER BY valor_top DESC
         LIMIT 24
     ) AS top10
    ) AS valor_top_10_pct,
    (SELECT ROUND(SUM(l.valor_lance_final), 2)
     FROM lote l
     WHERE l.id_arrematante IS NOT NULL
    ) AS valor_total_geral;
```
Resultado: top 24 arrematantes (10% de 243) somam R$ 456.532.129,17 de um total de R$ 3.087.769.016,23 → **~14,78%**.

**Versão robusta (função de janela, curva completa):**
```sql
WITH gasto_por_arrematante AS (
    SELECT a.id_arrematante, a.nome, SUM(l.valor_lance_final) AS valor_gasto
    FROM arrematante a
    JOIN lote l ON l.id_arrematante = a.id_arrematante
    GROUP BY a.id_arrematante, a.nome
)
SELECT
    nome, valor_gasto,
    ROUND(SUM(valor_gasto) OVER (ORDER BY valor_gasto DESC) /
          SUM(valor_gasto) OVER () * 100, 2) AS pct_acumulado
FROM gasto_por_arrematante
ORDER BY valor_gasto DESC;
```
**Conceito novo:** funções de janela (`SUM() OVER (...)`) e CTE (`WITH ... AS`). Diferente de `GROUP BY`, a função de janela mantém cada linha visível enquanto calcula uma agregação progressiva (soma acumulada) ou total geral repetido em cada linha.

As duas versões se validaram mutuamente (14,78% ≈ 14,79% na linha 24 da curva completa).

### Insight
**Distribuição de valor surpreendentemente equilibrada — sem efeito Pareto extremo.** O maior arrematante isolado representa apenas 0,77% do total; são necessários 42 arrematantes (17% do total de 243) para acumular ¼ do valor movimentado. Conclusão: não há um pequeno grupo de "baleias" dominando o mercado — o valor está distribuído entre um número grande de compradores recorrentes de porte similar.

**Bloco 4 (Comportamento do arrematante) concluído.**

## Pergunta 10 (Bloco 1)

> Qual a taxa de sucesso de venda na 1ª praça vs. 2ª vs. 3ª?

```sql
SELECT
    p.numero_praca,
    COUNT(*) AS total_ofertado,
    SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) AS total_vendido,
    ROUND(SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS taxa_venda_percentual
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN praca p ON p.Id_praca = le.Id_praca
GROUP BY p.numero_praca
ORDER BY p.numero_praca;
```

Resultado (atualizado em 31/07/2026, após correção da numeração de praça — Dia 9):
1ª praça 24,58% (20.027 ofertados), 2ª praça 24,87% (15.121, inalterado), 3ª praça (agora só praça única de verdade) 64,67% (150 ofertados). Validação: soma bate com os totais gerais (20.027+15.121+150=35.298).

*Resultado original, antes da correção: 1ª praça 24,79% (18.099), 2ª praça 24,87% (15.121), 3ª praça 25,65% (2.078).*

### Insight
**Taxa de sucesso praticamente estável entre 1ª e 2ª praça** — não se confirma a crença comum de que a 2ª praça (com desconto) venderia proporcionalmente mais que a 1ª. **Achado relevante após a correção:** a "praça única" de fato (removidos os 891 casos que eram, na verdade, "1ª praça" mal rotulada) tem taxa de conversão muito superior às demais — 64,67%, contra ~24-25% nas praças 1 e 2. Hipótese: a modalidade de praça única pode ser aplicada pelo juiz justamente em casos com maior probabilidade de venda (ex.: interessado pré-identificado, bem de alta liquidez), o que explicaria a taxa de sucesso muito maior.

## Pergunta 11 (Bloco 1 — última do bloco)

> Existe correlação entre número de praças necessárias e a comarca responsável?

```sql
SELECT
    c.comarca,
    COUNT(*) AS total_lotes_vendidos,
    ROUND(AVG(p.numero_praca), 2) AS media_numero_praca
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN processo pr ON pr.id_processo = le.id_processo
JOIN cartorio c ON c.Id_cartorio = pr.id_cartorio
JOIN praca p ON p.Id_praca = le.Id_praca
WHERE l.id_arrematante IS NOT NULL
GROUP BY c.comarca
ORDER BY media_numero_praca ASC;
```

**Encadeamento de 4 `JOIN`s**, com duas ramificações a partir de `leilao` (uma para `processo`→`cartorio`, outra para `praca`).

Resultado: 47 comarcas, variando de 1,44 (Aparecida de Goiânia) a 1,70 (Parintins) praças em média.

### Insight
**Eficiência de venda bastante homogênea entre comarcas** — variação de 0,26 entre os extremos, maior que a vista entre categorias de lote ou faixas de valor, mas ainda modesta. Parintins se destaca isoladamente como caso mais lento, merecendo investigação pontual futura.

**Bloco 1 (Eficiência judicial) concluído** (restando pendente apenas a pergunta de "tempo até a venda", que depende de identificar o mesmo bem físico entre tentativas — ver seção de pendências).

## Pergunta 12 (Bloco 5)

> Quais estados têm mais processos e maior valor movimentado?

```sql
SELECT
    loc.Estado,
    COUNT(DISTINCT pr.id_processo) AS qtd_processos,
    COUNT(*) AS total_lotes_ofertados,
    SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) AS total_lotes_vendidos,
    ROUND(SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN l.valor_lance_final ELSE 0 END), 2) AS valor_total_movimentado
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN processo pr ON pr.id_processo = le.id_processo
JOIN cartorio c ON c.Id_cartorio = pr.id_cartorio
JOIN localizacao loc ON loc.ID_local_cartorio = c.ID_local_cartorio
GROUP BY loc.Estado
ORDER BY valor_total_movimentado DESC;
```

**Técnica destacada:** `COUNT(DISTINCT pr.id_processo)` para não contar o mesmo processo mais de uma vez (um processo pode ter vários lotes).

Resultado: 14 estados no total — confirmado como sendo a área real de atuação da empresa fictícia simulada no projeto (não uma perda de dados). São Paulo lidera com folga (R$ 537,2 milhões, ~50% acima do 2º colocado, Minas Gerais).

### Insight
Forte correlação entre volume de atividade judicial e valor movimentado — sem estados "fora da curva". Estados se agrupam naturalmente em 3 faixas de porte (grande: SP/MG/RJ; médio: SC/RS/MS/CE/PE/GO/BA/AM; menor: ES/AP/PA).

## Pergunta 13 (Bloco 5 — última do bloco)

> A taxa de sucesso de venda varia por estado?

```sql
SELECT
    loc.Estado,
    COUNT(*) AS total_lotes_ofertados,
    SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) AS total_lotes_vendidos,
    ROUND(SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS taxa_venda_percentual
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN processo pr ON pr.id_processo = le.id_processo
JOIN cartorio c ON c.Id_cartorio = pr.id_cartorio
JOIN localizacao loc ON loc.ID_local_cartorio = c.ID_local_cartorio
GROUP BY loc.Estado
ORDER BY taxa_venda_percentual DESC;
```

### Achado metodológico relevante
Os resultados desta pergunta vieram **idênticos, casa decimal por casa decimal**, aos da Pergunta 7 (taxa de conversão por leiloeiro). Investigação confirmou a causa: o modelo de negócio simulado define **um leiloeiro titular por estado** (com possibilidade de uso de prepostos para leilões simultâneos, sempre registrados sob o leiloeiro titular) — ou seja, existe uma relação 1:1 entre `leiloeiro` e `Estado` neste conjunto de dados.

### Insight
**A "taxa por estado" não é uma métrica independente neste modelo** — é estruturalmente idêntica à performance do leiloeiro responsável por aquele estado. Registrado como nota metodológica importante para o relatório: não vale a pena apresentar as duas visões (geográfica e por leiloeiro) como insights distintos, pois descrevem exatamente o mesmo fenômeno sob rótulos diferentes.

**Bloco 5 (Geografia) concluído.**

## Pergunta 14 (Bloco 6)

> Existe um "melhor mês" para vender?

```sql
SELECT
    MONTH(p.data_fechamento) AS mes,
    COUNT(*) AS total_ofertado,
    SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) AS total_vendido,
    ROUND(SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS taxa_venda_percentual,
    ROUND(SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN l.valor_lance_final ELSE 0 END), 2) AS valor_total_vendido
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN praca p ON p.Id_praca = le.Id_praca
GROUP BY MONTH(p.data_fechamento)
ORDER BY mes;
```

**Técnica nova:** função `MONTH()` para extrair o mês de uma data, agrupando todos os anos juntos (padrão sazonal recorrente). Validação: somas batem com os totais gerais.

### Insight
Melhor mês em conversão: Julho (26,36%). Pior: Dezembro (23,22%) — diferença de 3,14 p.p., a maior variação sazonal observada no projeto até aqui. Fim de ano (Out-Dez) consistentemente mais fraco. Valor movimentado não segue exatamente o mesmo padrão da taxa (Março lidera em valor, com taxa apenas mediana) — sugerindo lotes de maior valor unitário vendidos naquele mês.

## Pergunta 15 (Bloco 6 — última pergunta do documento original)

> O dia da semana influencia na taxa de venda?

```sql
SELECT
    p.dia_semana,
    COUNT(*) AS total_ofertado,
    SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) AS total_vendido,
    ROUND(SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS taxa_venda_percentual
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN praca p ON p.Id_praca = le.Id_praca
GROUP BY p.dia_semana
ORDER BY FIELD(p.dia_semana, 'domingo', 'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado');
```

**Técnica nova:** `ORDER BY FIELD(coluna, valor1, valor2, ...)` para impor uma ordem customizada (cronológica) em vez da ordenação alfabética padrão de uma coluna de texto.

### Insight
Taxa de conversão praticamente uniforme entre dias da semana (24,46% a 25,36% — a menor variação observada em todo o projeto). Achado mais relevante foi de **volume**, não de taxa: quarta-feira concentra 36% de todos os lotes ofertados (12.777 de 35.298) — forte convenção operacional do setor para marcar encerramentos de praça, sem relação com maior chance de venda.

**Bloco 6 (Sazonalidade) concluído.** Com isso, todos os 6 blocos originais do documento de perguntas foram percorridos.

## Status geral ao final do Dia 8

15 perguntas do documento original respondidas e documentadas. Seguem pendentes: a pergunta extra de deságio real entre praças (Bloco 2) e a pergunta de tempo até a venda (Bloco 1) — ambas exigem uma investigação mais aprofundada, retomada em sessão futura.

---

# DIA 9

**Data:** 28/07/2026
**Objetivo do dia:** Investigar e resolver a pendência de "tempo até a venda" / "deságio entre praças", identificada nos Dias 8/9 anteriores como dependente de uma forma de ligar o mesmo bem físico entre diferentes tentativas de venda.

## 1. Investigação inicial: colunas não utilizadas do `leilao_bruto`

Revisitadas as colunas `Lote` e `ID_Lote` (nunca usadas até então). Constatado que:
- **`Lote`** permanece constante entre diferentes linhas/praças do mesmo bem físico (chave real de identificação do bem)
- **`ID_Lote`** varia a cada linha, funcionando como um identificador de tentativa (semelhante a `Item_ID`)
- **`SubLote`** identifica sub-itens dentro de um mesmo `Lote`

Query usada para investigar um caso concreto:
```sql
SELECT Processo, Lote, ID_Lote, SubLote, Praca, Data_abertura, Item_ID
FROM leilao_bruto
WHERE Processo = '000009080' AND Lote = 1
ORDER BY Praca, SubLote;
```

## 2. Regra de negócio esclarecida: significado da coluna `Praca`

Definido pelo autor do projeto: os valores da coluna `Praca` no `leilao_bruto` não são uma contagem ordinal contínua — `1` e `2` representam 1ª e 2ª praça de um leilão bifásico, enquanto `3` representa uma modalidade distinta: **praça única** (leilão que se inicia e se encerra em uma única sessão, determinada pelo juiz). Se um lote em praça única não obtém êxito, o processo pode ser reiniciado com um novo leilão bifásico (1ª/2ª praça) — nesse caso, a numeração antiga de "praça única" (3) fica "órfã" de uma 1ª praça correspondente, violando a regra de negócio de que toda 2ª praça deve ter uma 1ª praça anterior.

## 3. Detecção do problema real: inconsistência de numeração

Investigação de um caso concreto (`Processo 000009080`, `Lote 1`) revelou uma aparente inversão cronológica entre praças 2 e 3.

**Tentativa inicial (gerou falso positivo)** — comparação de datas como **texto** (`VARCHAR`), sem conversão:
```sql
-- ERRO: comparação textual de dd/mm/aaaa não reflete ordem cronológica real
-- (ex.: '26/02/2020' comparado como texto aparenta ser maior que '02/03/2020')
SELECT DISTINCT
    b1.Processo, b1.Lote,
    b1.Praca AS praca_x, b1.Data_abertura AS data_x,
    b2.Praca AS praca_y, b2.Data_abertura AS data_y
FROM leilao_bruto b1
JOIN leilao_bruto b2
    ON b1.Processo = b2.Processo
    AND b1.Lote = b2.Lote
    AND b1.Praca < b2.Praca
    AND b1.Data_abertura > b2.Data_abertura;
```

**Versão corrigida**, usando `STR_TO_DATE()` para comparação cronológica real — foi essa que revelou o padrão sistemático (inversão sempre entre Praça 2 e Praça 3, nunca entre 1 e 2):
```sql
SELECT DISTINCT
    b1.Processo, b1.Lote,
    b1.Praca AS praca_x, b1.Data_abertura AS data_x,
    b2.Praca AS praca_y, b2.Data_abertura AS data_y
FROM leilao_bruto b1
JOIN leilao_bruto b2
    ON b1.Processo = b2.Processo
    AND b1.Lote = b2.Lote
    AND b1.Praca < b2.Praca
    AND STR_TO_DATE(b1.Data_abertura, '%d/%m/%Y') > STR_TO_DATE(b2.Data_abertura, '%d/%m/%Y');
```

Com a comparação corrigida, identificado um padrão sistemático e real: em diversos processos, a "Praça 3" (praça única) tem data anterior à "Praça 2" do mesmo Lote — confirmando a hipótese de negócio (praça única antiga + novo leilão bifásico posterior, com a numeração antiga nunca reajustada).

**Queries de validação de escopo:**
```sql
-- Contagem de pares Processo/Lote afetados
SELECT COUNT(DISTINCT b1.Processo, b1.Lote) AS qtd_afetados
FROM leilao_bruto b1
JOIN leilao_bruto b2
    ON b1.Processo = b2.Processo AND b1.Lote = b2.Lote
    AND b1.Praca = 2 AND b2.Praca = 3
    AND STR_TO_DATE(b2.Data_abertura, '%d/%m/%Y') < STR_TO_DATE(b1.Data_abertura, '%d/%m/%Y');
-- Resultado: 891

-- Confirmação de que nenhum caso já tinha uma "Praça 1" pré-existente (sem risco de conflito)
SELECT DISTINCT b1.Processo, b1.Lote
FROM leilao_bruto b1
JOIN leilao_bruto b2
    ON b1.Processo = b2.Processo AND b1.Lote = b2.Lote
    AND b1.Praca = 2 AND b2.Praca = 3
    AND STR_TO_DATE(b2.Data_abertura, '%d/%m/%Y') < STR_TO_DATE(b1.Data_abertura, '%d/%m/%Y')
WHERE EXISTS (
    SELECT 1 FROM leilao_bruto b3
    WHERE b3.Processo = b1.Processo AND b3.Lote = b1.Lote AND b3.Praca = 1
);
-- Resultado: vazio (0 conflitos)
```

**Escopo do problema, após validações (com contagem confirmada de forma consistente):** 891 pares de Processo/Lote afetados, sem nenhum conflito com uma "Praça 1" pré-existente.

## 4. Correção aplicada

Estratégia definida pelo autor do projeto: renumerar a "Praça 3" órfã para "Praça 1" nos 891 casos identificados, respeitando a ordem cronológica real das datas — resolvendo a violação da regra de negócio sem necessidade de alterar datas (uma vez que o banco é fictício, mas essa abordagem preserva a coerência histórica dos dados).

```sql
CREATE TEMPORARY TABLE casos_para_corrigir AS
SELECT DISTINCT b1.Processo, b1.Lote
FROM leilao_bruto b1
JOIN leilao_bruto b2
    ON b1.Processo = b2.Processo AND b1.Lote = b2.Lote
    AND b1.Praca = 2 AND b2.Praca = 3
    AND STR_TO_DATE(b2.Data_abertura, '%d/%m/%Y') < STR_TO_DATE(b1.Data_abertura, '%d/%m/%Y');

SET SQL_SAFE_UPDATES = 0;
UPDATE leilao_bruto b
JOIN casos_para_corrigir c ON b.Processo = c.Processo AND b.Lote = c.Lote
SET b.Praca = 1
WHERE b.Praca = 3;
SET SQL_SAFE_UPDATES = 1;
```

### Incidentes técnicos durante a correção
- **Erro 1175** (modo de atualização segura) — resolvido com `SET SQL_SAFE_UPDATES = 0` (mesma solução do Dia 3)
- **Timeout/queda de conexão** durante o `UPDATE` — resolvido criando índice `idx_processo_lote (Processo, Lote)` em `leilao_bruto` (mesma lição do Dia 3: ausência de índice em colunas de `JOIN` causa lentidão severa em tabelas grandes)
- **Tabela temporária perdida** após a queda de conexão — comportamento esperado de `TEMPORARY TABLE` (existe apenas durante a sessão que a criou); recriada normalmente após reconexão
- **Contagem divergente (1928 vs 891)** durante a validação — investigado e atribuído a uma consulta residual de outra execução, não a um problema real; reconfirmado que o método correto retorna consistentemente 891

### Validação da correção
Confirmado, após o `UPDATE`: nenhuma inversão residual entre praças (`COUNT = 0`), nenhuma perda de linha em `leilao_bruto` (mantém 35.298), e nenhum dos 891 casos permaneceu com `Praca = 3`.

## 5. Repropagação da correção para o modelo normalizado

Como `praca` e `leilao` já haviam sido populadas antes dessa correção (no Dia 1), foi necessário repopulá-las a partir do `leilao_bruto` já corrigido:

```sql
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE leilao;
TRUNCATE TABLE praca;

INSERT INTO praca (numero_praca, data_abertura, data_fechamento, dia_semana)
SELECT DISTINCT b.Praca, STR_TO_DATE(b.Data_abertura, '%d/%m/%Y'),
       STR_TO_DATE(b.Data_fechamento, '%d/%m/%Y'), b.Dia_semana
FROM leilao_bruto b
WHERE b.Data_abertura IS NOT NULL;

INSERT INTO leilao (Id_praca, id_lote, id_processo, id_leiloeiro)
SELECT DISTINCT p.Id_praca, lt.id_lote, pr.id_processo, le.id_leiloeiro
FROM leilao_bruto b
LEFT JOIN praca p ON p.numero_praca = b.Praca
    AND p.data_abertura = STR_TO_DATE(b.Data_abertura, '%d/%m/%Y')
    AND p.data_fechamento = STR_TO_DATE(b.Data_fechamento, '%d/%m/%Y')
    AND p.dia_semana = b.Dia_semana
LEFT JOIN lote lt ON lt.item_id_origem = b.Item_ID
LEFT JOIN processo pr ON pr.numero_processo_origem = b.Processo
LEFT JOIN leiloeiro le ON le.nome = b.Leiloeiro;

SET FOREIGN_KEY_CHECKS = 1;
```

**Nota técnica:** com as FOREIGN KEYS já ativas (criadas no Dia 2), foi necessário desabilitar temporariamente a checagem de integridade (`FOREIGN_KEY_CHECKS = 0`) para permitir o `TRUNCATE` de `praca` (referenciada por `leilao`), reabilitando-a logo em seguida.

### Resultado e validação final
- `praca`: **11.274** registros (redução de 11.981 para 11.274 — esperada e correta: a correção da numeração fez com que combinações antes tratadas como distintas por erro de rótulo se fundissem em registros já existentes de mesma data/dia da semana)
- `leilao`: mantido em **35.298** (nenhuma perda de linha)
- Checagem de unicidade em `praca` (numero_praca + datas + dia_semana): sem duplicatas
- Checagem de órfãos (`leilao.Id_praca` → `praca.Id_praca`): **0**, integridade confirmada

`lote` não precisou de alteração — a numeração de praça nunca foi armazenada diretamente nessa tabela.

## Pendências para retomar

Com a fonte de dados agora corrigida, é necessário:
1. **Revisar as 3 perguntas que utilizaram `numero_praca`**, pois seus resultados podem ter mudado com a correção:
   - Pergunta 6 (valor inicial × praça média)
   - Pergunta 10 (taxa de venda por número de praça)
   - Pergunta 11 (comarca × praça média)
2. **Retomar as duas pendências originais** que motivaram toda essa investigação:
   - Deságio real entre praças (1ª vs 2ª, mesmo bem físico)
   - Tempo até a venda (data da 1ª tentativa até a venda efetiva)

---

# DIA 10

**Data:** 31/07/2026
**Objetivo do dia:** Revisar as perguntas afetadas pela correção de numeração de praça (Dia 9) e registrar pendências para a próxima fase do projeto.

## Revisão da Pergunta 6 (valor inicial × praça média)

Resultado atualizado: Baixo (< 50k) 1,51 / Médio (50k-200k) 1,45 / Alto (> 200k) 1,42 (antes: 1,60 / 1,55 / 1,52). Todas as faixas caíram de forma proporcional (~0,09 a 0,10 cada) — a correção não alterou a direção nem a magnitude relativa da tendência identificada originalmente. Conclusão de negócio mantida (ver Pergunta 6 revisada).

## Revisão da Pergunta 10 (taxa de venda por número de praça)

Resultado atualizado, com mudança estrutural relevante:

| Praça | Antes | Depois |
|---|---|---|
| 1ª | 18.099 / 24,79% | 20.027 / 24,58% |
| 2ª | 15.121 / 24,87% | 15.121 / 24,87% (inalterada) |
| 3ª (única) | 2.078 / 25,65% | **150 / 64,67%** |

**Achado novo relevante:** isolada a "praça única" de fato (após remover os 891 casos que eram, na verdade, 1ª praça mal rotulada), sua taxa de conversão é dramaticamente superior (64,67%) às praças 1 e 2 (~24-25%). Ver Pergunta 10 revisada para a hipótese levantada.

## Revisão da Pergunta 11 (comarca × praça média)

```sql
SELECT
    c.comarca,
    COUNT(*) AS total_lotes_vendidos,
    ROUND(AVG(p.numero_praca), 2) AS media_numero_praca
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN processo pr ON pr.id_processo = le.id_processo
JOIN cartorio c ON c.Id_cartorio = pr.id_cartorio
JOIN praca p ON p.Id_praca = le.Id_praca
WHERE l.id_arrematante IS NOT NULL
GROUP BY c.comarca
ORDER BY media_numero_praca ASC;
```

**Achado principal: Parintins deixou de ser outlier.**

| | Antes | Depois |
|---|---|---|
| Parintins | **1,70** (destacadamente a mais lenta) | **1,51** (43º de 47, dentro do intervalo normal) |
| Amplitude entre comarcas | 0,26 (1,44 a 1,70) | **0,17** (1,36 a 1,53) |
| Mais rápida | Aparecida de Goiânia (1,44) | São Paulo / Caxias do Sul, empatadas (1,36) |

Isso confirma que Parintins concentrava vários dos 891 casos de "praça única" mal rotulada corrigidos no Dia 9 — o que inflava artificialmente sua média. Com a correção, ela caiu para dentro do intervalo normal das demais comarcas.

### Insight (atualizado)
A eficiência de venda continua homogênea entre comarcas — e ficou **ainda mais homogênea** após a correção, sem nenhum outlier isolado. O achado de "Parintins como caso especial" (Dia 8) foi **desmentido** pela correção — um bom exemplo de como um erro de dado pode gerar uma falsa pista de investigação, corrigida com a devida auditoria da fonte. Conclusão de negócio reforçada: a comarca não é um fator relevante na velocidade de venda de um lote.

## Contexto sobre a natureza dos dados (esclarecido pelo autor do projeto)

Os dados de `leilao_bruto` foram gerados via fórmulas no Excel, especificamente para fins de estudo/aplicação de conhecimentos de modelagem e SQL — não pretendem replicar fielmente a distribuição estatística de um leilão judicial real. Isso explica, por exemplo, por que a distribuição de vendas entre praças no dataset atual não reflete a realidade de mercado (ver pendência abaixo).

## Pendências registradas para fases futuras do projeto

### 1. Ajuste de realismo estatístico dos dados (para uma próxima geração de dados)
Na realidade de um leilão judicial, a **grande maioria das vendas (próximo de 99%)** ocorre na 2ª praça, já que o valor de abertura da 2ª praça costuma cair para **40-50%** do valor da 1ª praça, tornando-a muito mais atrativa. O dataset atual não reflete esse padrão. Para uma próxima versão/expansão do projeto (após concluir esta primeira versão e publicar os dashboards no Power BI / GitHub / LinkedIn), o objetivo é cadastrar novos leilões buscando aproximar a proporção de vendas em 2ª praça para a faixa de **70-80%**, tornando a base mais representativa da realidade, sem necessariamente replicar o extremo de 99%.

### 2. Decisão pendente: atualizar o CSV/planilha-base original?
Questão em aberto: seria necessário retroagir a correção de numeração de praça (Dia 9) até a planilha/CSV original que gerou o `leilao_bruto`, ou a correção aplicada diretamente na tabela `leilao_bruto` (banco) é suficiente? Ponto a favor de manter a correção só no banco: as queries de análise são construídas para funcionar independentemente da origem dos dados — o que muda com novos leilões cadastrados são os indicadores (resultados), não a lógica das consultas. A decisão final sobre alterar ou não a fonte original (CSV) fica para quando a expansão de dados (pendência 1) for realizada.

---

# DIA 11

**Data:** 31/07/2026
**Objetivo do dia:** Resolver definitivamente as duas pendências analíticas (Perguntas 16 e 17), estabelecendo a ligação entre linhas de `lote` que representam o mesmo bem físico em praças diferentes.

## 1. Definição da chave de ligação entre praças do mesmo bem

Revisitada a proposta inicial de usar apenas `Processo + Lote` como chave — identificado que essa combinação é **insuficiente**, pois um mesmo `Lote` pode conter múltiplos `SubLote` (itens individuais dentro do mesmo lote judicial), o que misturaria itens diferentes como se fossem o mesmo bem.

**Chave correta definida:** `Processo + Lote + SubLote`, identificando o item individual através de diferentes tentativas de praça — resolvendo o cenário descrito pelo autor do projeto ("um leilão com 3 sublotes, 1 vendido na 1ª praça, os outros 2 voltam para a 2ª — quando foi essa 2ª?").

Validada a unicidade da chave antes de prosseguir:
```sql
SELECT Processo, Lote, SubLote, Praca, COUNT(*)
FROM leilao_bruto
GROUP BY Processo, Lote, SubLote, Praca
HAVING COUNT(*) > 1;
```
Resultado: vazio — confirma no máximo uma tentativa por item, por praça.

## 2. Estrutura de suporte adicionada em `lote`

```sql
ALTER TABLE lote ADD COLUMN processo_origem VARCHAR(50);
ALTER TABLE lote ADD COLUMN lote_origem VARCHAR(50);
ALTER TABLE lote ADD COLUMN sublote_origem VARCHAR(50);

UPDATE lote l
JOIN leilao_bruto b ON b.Item_ID = l.item_id_origem
SET l.processo_origem = b.Processo,
    l.lote_origem = b.Lote,
    l.sublote_origem = b.SubLote;
```
Validado: 0 linhas com `processo_origem IS NULL` (todas as 35.298 linhas populadas corretamente).

**Índice composto criado** para suportar o auto-JOIN necessário nas perguntas seguintes, evitando timeout (mesma lição do Dia 3/9):
```sql
ALTER TABLE lote ADD INDEX idx_origem_composto (processo_origem, lote_origem, sublote_origem);
```
*Nota: a ausência inicial desse índice causou uma queda de conexão (Error 2013) na primeira tentativa de contagem — resolvida criando o índice antes de repetir a consulta.*

Validada a integridade da relação 1ª↔2ª praça (contagem idêntica nos dois sentidos): **15.121** itens possuem tanto 1ª quanto 2ª praça.

## 3. Pergunta 16 — Deságio real entre praças

```sql
SELECT
    COUNT(*) AS qtd_itens,
    ROUND(AVG((l1.valor_inicial - l2.valor_inicial) / l1.valor_inicial) * 100, 2) AS desagio_medio_percentual
FROM lote l1
JOIN leilao le1 ON le1.id_lote = l1.id_lote
JOIN praca p1 ON p1.Id_praca = le1.Id_praca AND p1.numero_praca = 1
JOIN lote l2
    ON l2.processo_origem = l1.processo_origem
    AND l2.lote_origem = l1.lote_origem
    AND l2.sublote_origem = l1.sublote_origem
JOIN leilao le2 ON le2.id_lote = l2.id_lote
JOIN praca p2 ON p2.Id_praca = le2.Id_praca AND p2.numero_praca = 2;
```

**Resultado: 15.121 itens, deságio médio de 20,17%** entre o valor inicial da 1ª e da 2ª praça.

### Insight
Em média, quando um bem não vende na 1ª praça, seu valor de abertura cai 20,17% para a 2ª tentativa. Comparado ao padrão de mercado real mencionado pelo autor do projeto (desconto de 40-50%), o dataset fictício está bem abaixo do esperado — registrado junto à pendência de realismo estatístico já anotada no Dia 10.

**Cruzamento com a Pergunta 4 (ágio médio, 15,01%):** mesmo com a disputa entre arrematantes recuperando ~15% de ágio sobre o valor de abertura da 2ª praça, isso não compensa totalmente o deságio de 20,17% aplicado — o valor final de venda na 2ª praça tende a ficar, em média, ainda abaixo do valor de abertura original da 1ª praça (estimativa aproximada: 100 → 79,83 → ~91,80, um resíduo de ~8% abaixo do valor inicial da 1ª praça).

## 4. Pergunta 17 — Tempo até a venda

### Primeira tentativa e bug de auto-JOIN identificado

Query original com bug (sem excluir `l2 = l1`):
```sql
-- BUG: sem "l2.id_lote != l1.id_lote", cada linha casa consigo mesma além
-- de casar com sua verdadeira contraparte de 2ª praça, duplicando o resultado
SELECT
    ROUND(AVG(
        DATEDIFF(
            CASE WHEN l1.id_arrematante IS NOT NULL THEN p1.data_fechamento ELSE p2.data_fechamento END,
            p1.data_abertura
        )
    ), 1) AS media_dias_ate_venda,
    COUNT(*) AS qtd_itens_vendidos
FROM lote l1
JOIN leilao le1 ON le1.id_lote = l1.id_lote
JOIN praca p1 ON p1.Id_praca = le1.Id_praca AND p1.numero_praca = 1
LEFT JOIN lote l2
    ON l2.processo_origem = l1.processo_origem
    AND l2.lote_origem = l1.lote_origem
    AND l2.sublote_origem = l1.sublote_origem
LEFT JOIN leilao le2 ON le2.id_lote = l2.id_lote
LEFT JOIN praca p2 ON p2.Id_praca = le2.Id_praca AND p2.numero_praca = 2
WHERE l1.id_arrematante IS NOT NULL OR l2.id_arrematante IS NOT NULL;
-- Resultado: 10.054 — matematicamente impossível (esperado no máximo 8.683 = 4.923 + 3.760)
```

Uma primeira versão da query retornou 10.054 itens — número matematicamente impossível, já que o máximo esperado (vendidos na 1ª + vendidos na 2ª) era 8.683 (4.923 + 3.760, conforme Pergunta 10 revisada).

**Query de investigação do caso concreto (`id_lote = 3`)** que revelou a causa raiz:
```sql
SELECT
    l1.id_lote AS id_lote_1a,
    l1.processo_origem, l1.lote_origem, l1.sublote_origem,
    l2.id_lote AS id_lote_2a,
    le2.Id_praca AS leilao_id_praca_2a,
    p2.Id_praca AS praca_id_praca_2a,
    p2.numero_praca
FROM lote l1
LEFT JOIN lote l2
    ON l2.processo_origem = l1.processo_origem
    AND l2.lote_origem = l1.lote_origem
    AND l2.sublote_origem = l1.sublote_origem
LEFT JOIN leilao le2 ON le2.id_lote = l2.id_lote
LEFT JOIN praca p2 ON p2.Id_praca = le2.Id_praca AND p2.numero_praca = 2
WHERE l1.id_lote = 3;
-- Resultado: 2 linhas — uma com l2.id_lote = 3 (a própria l1, "casando consigo mesma")
-- e outra com l2.id_lote = 20179 (a verdadeira 2ª praça daquele item)
```

**Causa identificada:** clássico problema de auto-JOIN (self-join) — sem uma condição excluindo `l2.id_lote != l1.id_lote`, cada linha "casava consigo mesma" além de casar com sua verdadeira contraparte de 2ª praça, duplicando o resultado.

**Correção:** adicionada a condição `AND l2.id_lote != l1.id_lote` ao `JOIN`.

### Segunda divergência: inconsistência de "dupla venda"
Após a correção do auto-JOIN, o resultado veio em 8.219 — ainda 464 a menos que o esperado (8.683). Investigação:
```sql
-- Conta itens marcados como vendidos nas duas praças (1ª e 2ª) simultaneamente
SELECT COUNT(*)
FROM lote l1
JOIN leilao le1 ON le1.id_lote = l1.id_lote
JOIN praca p1 ON p1.Id_praca = le1.Id_praca AND p1.numero_praca = 1
JOIN lote l2
    ON l2.processo_origem = l1.processo_origem
    AND l2.lote_origem = l1.lote_origem
    AND l2.sublote_origem = l1.sublote_origem
    AND l2.id_lote != l1.id_lote
JOIN leilao le2 ON le2.id_lote = l2.id_lote
JOIN praca p2 ON p2.Id_praca = le2.Id_praca AND p2.numero_praca = 2
WHERE l1.id_arrematante IS NOT NULL
  AND l2.id_arrematante IS NOT NULL;
-- Resultado: 464
```
Revelada uma inconsistência real no dataset: **464 itens estavam marcados como vendidos tanto na 1ª quanto na 2ª praça simultaneamente** (logicamente impossível — um bem só pode ser vendido uma vez). A conta se fechou perfeitamente: 8.219 + 464 = 8.683.

### Correção da inconsistência de dupla venda
Definido que a venda válida é sempre a da 1ª praça (a 2ª praça não deveria ter sido ofertada/vendida se o item já havia sido arrematado antes). Removida a marcação incorreta de `id_arrematante` nas 464 linhas de 2ª praça correspondentes:

```sql
CREATE TEMPORARY TABLE casos_dupla_venda AS
SELECT DISTINCT l2.id_lote
FROM lote l1
JOIN leilao le1 ON le1.id_lote = l1.id_lote
JOIN praca p1 ON p1.Id_praca = le1.Id_praca AND p1.numero_praca = 1
JOIN lote l2 ON l2.processo_origem = l1.processo_origem
    AND l2.lote_origem = l1.lote_origem AND l2.sublote_origem = l1.sublote_origem
    AND l2.id_lote != l1.id_lote
JOIN leilao le2 ON le2.id_lote = l2.id_lote
JOIN praca p2 ON p2.Id_praca = le2.Id_praca AND p2.numero_praca = 2
WHERE l1.id_arrematante IS NOT NULL AND l2.id_arrematante IS NOT NULL;

SET SQL_SAFE_UPDATES = 0;
UPDATE lote l
JOIN casos_dupla_venda c ON c.id_lote = l.id_lote
SET l.id_arrematante = NULL;
SET SQL_SAFE_UPDATES = 1;
```

**Validação final** (deve retornar 0):
```sql
SELECT COUNT(*)
FROM lote l1
JOIN leilao le1 ON le1.id_lote = l1.id_lote
JOIN praca p1 ON p1.Id_praca = le1.Id_praca AND p1.numero_praca = 1
JOIN lote l2
    ON l2.processo_origem = l1.processo_origem
    AND l2.lote_origem = l1.lote_origem
    AND l2.sublote_origem = l1.sublote_origem
    AND l2.id_lote != l1.id_lote
JOIN leilao le2 ON le2.id_lote = l2.id_lote
JOIN praca p2 ON p2.Id_praca = le2.Id_praca AND p2.numero_praca = 2
WHERE l1.id_arrematante IS NOT NULL AND l2.id_arrematante IS NOT NULL;
```
Validado: 0 casos de dupla venda restantes após a correção.

### Query final e resultado

```sql
SELECT
    ROUND(AVG(
        DATEDIFF(
            CASE WHEN l1.id_arrematante IS NOT NULL THEN p1.data_fechamento ELSE p2.data_fechamento END,
            p1.data_abertura
        )
    ), 1) AS media_dias_ate_venda,
    COUNT(*) AS qtd_itens_vendidos
FROM lote l1
JOIN leilao le1 ON le1.id_lote = l1.id_lote
JOIN praca p1 ON p1.Id_praca = le1.Id_praca AND p1.numero_praca = 1
LEFT JOIN lote l2 ON l2.processo_origem = l1.processo_origem
    AND l2.lote_origem = l1.lote_origem AND l2.sublote_origem = l1.sublote_origem
    AND l2.id_lote != l1.id_lote
LEFT JOIN leilao le2 ON le2.id_lote = l2.id_lote
LEFT JOIN praca p2 ON p2.Id_praca = le2.Id_praca AND p2.numero_praca = 2
WHERE l1.id_arrematante IS NOT NULL OR l2.id_arrematante IS NOT NULL;
```

**Resultado: 8.219 itens vendidos, média de 13,2 dias** desde a abertura da 1ª praça até a venda efetiva.

*Nota técnica: o resultado (8.219 / 13,2) permaneceu idêntico antes e depois da correção da dupla venda — explicado pelo fato de o `CASE WHEN` já priorizar a data da 1ª praça sempre que `l1.id_arrematante` estava preenchido, "blindando" essa query específica contra a inconsistência. A correção continua sendo necessária para a integridade geral dos dados e para outras análises que não têm essa lógica de prioridade.*

### Insight
Em média, um item leva **13,2 dias** desde a abertura da 1ª praça até ser efetivamente vendido — um prazo relativamente curto, compatível com editais que estabelecem janelas de disputa de poucos dias por sessão.

## Status final

**As 17 perguntas do projeto estão respondidas.** Todas as pendências técnicas registradas desde os Dias 6/8 foram resolvidas. Restam apenas as pendências de estrutura/dados já registradas no Dia 10 (ajuste de realismo estatístico para uma próxima geração de dados, preenchimento de placeholders de endereço, expansão de `localizacao`).

---

# DIA 12

**Data:** [preencher data desta sessão]
**Objetivo do dia:** Decisão estratégica sobre a pendência de realismo estatístico dos dados (registrada nos Dias 10/11).

## Decisão: manter o dataset atual para esta versão do projeto

Avaliada a possibilidade de ajustar os dados agora para refletir a proporção real de mercado (meta discutida: taxa de venda geral de 17,5%, com 95% das vendas concentradas em 2ª praça, e deságio médio de 40% entre 1ª e 2ª praça — valores dentro das faixas fornecidas pelo autor do projeto, com base em sua experiência de que a maioria das vendas reais ocorre em 2ª praça, já que o lance inicial nessa fase tem desconto de 40-50% sobre o valor de avaliação, contra 100% na 1ª praça).

**Decisão tomada:** não regerar os dados nesta fase. Como o projeto tem finalidade de portfólio, prioriza-se **concluir esta primeira versão** com o dataset atual — que, embora não reflita fielmente a distribuição estatística de um leilão judicial real, está **internamente consistente e validado** (sem inconsistências remanescentes, após as correções dos Dias 3, 9 e 11). Essa consistência interna é o que importa para demonstrar o processo de modelagem, normalização e análise.

**Plano para o futuro:** elaborar um **novo dataset (v2)**, já incorporando desde a origem os parâmetros de realismo discutidos:
- Taxa de venda geral: ~17,5%
- Distribuição das vendas: ~95% em 2ª praça, 5% dividido entre 1ª praça (casos excepcionais de bem muito abaixo do valor de mercado) e praça única
- Deságio médio entre 1ª e 2ª praça: ~40%

Essa nova versão poderá ser usada para atualizar o repositório (GitHub) e o material de portfólio após a conclusão e publicação desta primeira versão (dashboards no Power BI, LinkedIn).

## Pendências mantidas para a v2 do dataset
- Ajuste de realismo estatístico (parâmetros acima)
- Preenchimento de placeholders de endereço (`arrematante.endereco`, `lote.endereco`, `localizacao.Rua`)
- Expansão de `localizacao` com mais campos de endereço detalhado

## Próximo passo desta versão (v1)
Seguir para a construção dos dashboards no Power BI, usando o dataset atual (v1), já totalmente validado e com as 17 perguntas de negócio respondidas e documentadas.

---

# DIA 13

**Data:** [preencher data desta sessão]
**Objetivo do dia:** Iniciar a construção do relatório no Power BI, conectando-o ao banco MySQL (modelo v1, já validado).

## Discussão prévia: divisão de responsabilidades entre SQL e Power BI

Alinhado que a limpeza e estruturação pesada de dados já feita no MySQL (tratamento de valores sujos, normalização, correções de inconsistência) permanece no banco — trazendo benefícios de performance, reusabilidade e auditabilidade (scripts `.sql` versionáveis) que a limpeza feita só dentro do Power Query não ofereceria da mesma forma. O papel do Power BI nesta fase é: modelagem em DAX (medidas dinâmicas e interativas) e visualização — recriando a lógica das 17 perguntas já respondidas em SQL como medidas reutilizáveis e filtráveis, em vez de números fixos.

## Modo de conexão: Import (não DirectQuery)

Decidido usar o modo **Import** em vez de DirectQuery, pelos motivos:
- Volume de dados pequeno (~35 mil linhas na maior tabela) — Import é rápido e adequado
- Projeto de portfólio não exige dados "ao vivo"
- O conector MySQL do Power BI tem *query folding* limitado, tornando DirectQuery menos eficiente nesse banco especificamente

## Conexão estabelecida

- **Método de autenticação:** validação do Windows (não usuário/senha)
- **Campos de conexão:** "Servidor" = host; "Nome do banco de dados" = `leilao`
- **Tabelas importadas:** todas as 11 tabelas do modelo (`lote`, `arrematante`, `leiloeiro`, `leilao`, `praca`, `processo`, `cartorio`, `localizacao`, `comercial`, `juiz`, `diretor_cartorio`) — incluídas mesmo as com campos placeholder (`comercial`, `juiz`, `diretor_cartorio`), para manter flexibilidade de uso futuro no relatório

## Ajustes no Power Query Editor

### Tipos de coluna
- Colunas monetárias (`valor_inicial`, `valor_lance_final`, `comissao_leiloeiro`) definidas como **Decimal Fixo** (não Decimal comum) — evita o "ruído" de imprecisão de ponto flutuante já observado anteriormente no MySQL (ex.: somas retornando `3087769016.2302246` em vez de um valor limpo), e é semanticamente o tipo recomendado pelo Power BI para valores monetários (tratado internamente como "Moeda").

### Decisão sobre o número do processo
`numero_processo_origem` (e demais colunas de número de processo/identificadores textuais com zeros à esquerda) **mantido como texto**, não convertido para número — conversão para tipo numérico eliminaria os zeros à esquerda (ex.: `"032034875"` viraria `32034875`), quebrando a correspondência com a fonte original.

## Pendências para continuar
- Revisar/confirmar tipos de coluna nas demais tabelas
- Revisar relacionamentos detectados automaticamente pelo Power BI entre as tabelas importadas
- Iniciar a construção das medidas DAX correspondentes às 17 perguntas já respondidas em SQL

## Revisão de relacionamentos: tabela `arrematante` sem conexão

Após "Fechar e Aplicar", identificado na vista de Modelo que a tabela `arrematante` ficou **isolada**, sem nenhum relacionamento com o restante do modelo — o Power BI não detectou automaticamente a ligação `lote.id_arrematante` → `arrematante.id_arrematante`.

### Causa identificada: colunas de ID marcadas incorretamente como "Resumir por: Soma"

Ao tentar criar o relacionamento manualmente (Modelagem → Nova relação), a coluna `id_arrematante` aparecia sem destaque/comportamento estranho na lista de seleção. Causa: a coluna estava marcada com o símbolo **Σ** no modelo, que indica a propriedade **"Resumir por" (Summarize By) = Soma** — ou seja, o Power BI estava tratando `id_arrematante` como um valor numérico agregável (somável), e não como um identificador/chave de ligação entre tabelas.

**Nota importante para lembrar:** colunas de ID/chave (`id_lote`, `id_arrematante`, `id_leiloeiro`, `id_processo`, etc.) **nunca devem ter "Resumir por" configurado como Soma/Média/etc.** — isso não faz sentido semântico (somar IDs é uma operação sem significado) e pode interferir na criação/uso de relacionamentos. A correção é feita na **vista de Dados**, selecionando a coluna, e na faixa de opções (Estrutura de Tabela / Ferramentas de Coluna) trocando "Resumir por" de "Soma" para **"Não resumir"**.

### Correção aplicada
1. Corrigido `lote.id_arrematante` para "Não resumir"
2. Criado o relacionamento manualmente: `lote.id_arrematante` (muitos) → `arrematante.id_arrematante` (um), com "Pressuponha integridade referencial" ativado (seguro, pois já validado no MySQL que não existem referências órfãs nessa relação)

### Ação pendente de verificação
Revisar as demais colunas de ID em todas as 11 tabelas, corrigindo qualquer outra que esteja incorretamente marcada com "Resumir por: Soma" (identificadas visualmente pelo ícone Σ ao lado do nome da coluna na vista de Modelo).

---

# DIA 14

**Data:** [preencher data desta sessão]
**Objetivo do dia:** Investigar e corrigir uma inconsistência entre as colunas `resultado` e `id_arrematante` em `lote`, identificada durante a revisão dos dados no Power Query (Power BI).

## 1. Inconsistência identificada no Power Query

Durante a revisão da tabela `lote` já importada no Power BI, identificado visualmente que existiam linhas com `resultado = 'Positivo'` mas `id_arrematante` vazio — uma contradição lógica, já que "positivo" deveria implicar a existência de um arrematante vinculado. Isso impedia inclusive a criação do relacionamento `lote` ↔ `arrematante` no Power BI.

## 2. Investigação no MySQL

```sql
SELECT COUNT(*)
FROM lote
WHERE resultado = 'Positivo' AND id_arrematante IS NULL;
-- Resultado: 493
```

Investigados os 493 casos, divididos em dois grupos com causas distintas:

### Grupo 1 (467 casos): dessincronia remanescente da correção do Dia 11
```sql
SELECT COUNT(*)
FROM lote l1
JOIN lote l2
    ON l2.processo_origem = l1.processo_origem
    AND l2.lote_origem = l1.lote_origem
    AND l2.sublote_origem = l1.sublote_origem
    AND l2.id_lote != l1.id_lote
WHERE l1.resultado = 'Positivo' 
  AND l1.id_arrematante IS NULL
  AND l2.id_arrematante IS NOT NULL;
-- Resultado: 467
```
Esses itens possuem uma venda válida registrada em outra praça do mesmo bem — são, em sua maioria, os mesmos 464 casos corrigidos no Dia 11 (quando o `id_arrematante` fantasma foi removido da 2ª praça por "dupla venda"). Na ocasião, apenas a coluna `id_arrematante` foi corrigida; a coluna `resultado` (vinda diretamente do `leilao_bruto`, nunca tocada naquela correção) permaneceu desatualizada, ainda indicando "Positivo". A pequena diferença (467 vs. 464) foi investigada e atribuída a variações normais de contagem em casos-limite (itens com mais de duas linhas/praças), sem indicar problema adicional — confirmado que todos os valores originais de `Arrematante` nesses casos eram nomes reais e válidos.

### Grupo 2 (26-29 casos): nova inconsistência de origem — cabeçalho vazado
```sql
SELECT COUNT(*) FROM leilao_bruto WHERE Arrematante = 'Nomes arrematantes';
-- Resultado: 29
```
Identificado, ao investigar um caso concreto (`Processo 032899510`), que a coluna `Arrematante` continha o valor literal **`"Nomes arrematantes"`** — o texto do cabeçalho da coluna vazado para dentro dos dados, no mesmo padrão do problema `'DDD'` já identificado e corrigido no Dia 1 (durante a população da tabela `arrematante`). Como esse valor nunca foi filtrado (o filtro original excluía apenas `'0'` e `NULL`), essas linhas ficaram com `id_arrematante = NULL` (por não encontrar correspondência real no `JOIN`), mas a coluna `resultado` continuou incorretamente marcada como "Positivo".

## 3. Correção aplicada

```sql
-- Corrigir a inconsistência do cabeçalho vazado
UPDATE lote l
JOIN leilao_bruto b ON b.Item_ID = l.item_id_origem
SET l.resultado = 'Negativo'
WHERE b.Arrematante = 'Nomes arrematantes';

-- Sincronizar 'resultado' com id_arrematante para toda a tabela
-- (resolve o Grupo 1 e qualquer outro caso remanescente)
SET SQL_SAFE_UPDATES = 0;
UPDATE lote
SET resultado = CASE 
    WHEN id_arrematante IS NOT NULL THEN 'Positivo'
    ELSE 'Negativo'
END;
SET SQL_SAFE_UPDATES = 1;
```

*Nota técnica: o `UPDATE` de sincronização retornou `Rows matched: 35298, Changed: 0` — não por falha, mas porque, no momento em que rodou, a primeira query já havia deixado a tabela sincronizada, sem mais nenhuma linha divergente a alterar.*

## 4. Validação final

```sql
SELECT COUNT(*) FROM lote WHERE resultado = 'Positivo' AND id_arrematante IS NULL;  -- 0
SELECT COUNT(*) FROM lote WHERE resultado = 'Negativo' AND id_arrematante IS NOT NULL;  -- 0
```

Ambas retornaram **0** — coluna `resultado` agora 100% sincronizada com `id_arrematante` em toda a tabela `lote`.

## Nota sobre o Power BI (retomado na sequência desta sessão)

Registrado, para complementar posteriormente: durante a configuração do modelo no Power BI, identificado que colunas de ID (ex.: `id_arrematante`) precisam ter a propriedade "Resumir por" ajustada para "Não resumir" (ver detalhe no Dia 13) — o ícone Σ presente nessas colunas interferia na criação de relacionamentos manuais. Também identificada e resolvida a decisão de manter colunas de identificador com zero à esquerda (ex.: número de processo) como texto, evitando perda de dígitos na conversão para número.

## Fechamento da etapa de modelagem no Power BI

Após a correção da inconsistência `resultado`/`id_arrematante` no MySQL (seções 1-4 acima) e a atualização dos dados no Power BI (**Atualizar**, sem necessidade de reconectar do zero), a etapa de modelagem foi concluída com sucesso:

- Tipos de coluna revisados e corrigidos em todas as tabelas (colunas monetárias como Decimal Fixo; identificadores com zero à esquerda mantidos como texto)
- Colunas de ID (`id_arrematante`, `id_lote`, etc.) corrigidas de "Resumir por: Soma" para "Não resumir" em todas as tabelas que apresentavam o problema
- Relacionamento `lote.id_arrematante` → `arrematante.id_arrematante` criado com sucesso (após as correções acima, o Power BI passou a detectar/permitir a criação corretamente)
- Demais relacionamentos entre as 11 tabelas confirmados como corretos

**Modelo de dados no Power BI totalmente estabelecido e validado.** Próxima etapa: construção das medidas DAX, recriando a lógica das 17 perguntas de negócio já respondidas em SQL, de forma dinâmica e interativa.

---

# DIA 15

**Data:** [preencher data desta sessão]
**Objetivo do dia:** Iniciar a construção das medidas DAX no Power BI, começando por uma página de visão geral (overview) e pelas medidas do Bloco 4 (arrematante).

## 1. Medidas do Bloco 4 (arrematante) — equivalentes às Perguntas 1, 2 e 3

```dax
Qtd Lotes Comprados = 
COUNTROWS(
    FILTER(
        lote,
        NOT(ISBLANK(lote[id_arrematante]))
    )
)

Valor Total Gasto = 
SUMX(
    FILTER(
        lote,
        NOT(ISBLANK(lote[id_arrematante]))
    ),
    lote[valor_lance_final]
)

Ticket Medio = 
DIVIDE(
    [Valor Total Gasto],
    [Qtd Lotes Comprados]
)
```

**Conceitos DAX novos aplicados:**
- Medidas (calculadas dinamicamente conforme o contexto de filtro do visual) em vez de queries fixas — a diferença central de trabalhar com DAX em vez de SQL puro
- `FILTER(tabela, condição)` + `COUNTROWS`/`SUMX` como equivalente ao `WHERE` + agregação do SQL
- `SUMX(tabela_filtrada, expressão)` — soma linha por linha, equivalente ao `SUM(CASE WHEN...)` usado extensivamente em SQL ao longo do projeto
- `DIVIDE(numerador, denominador)` — função seguro contra divisão por zero (retorna `BLANK()` em vez de erro), preferível a `/` direto em DAX
- Medidas podem referenciar outras medidas (`Ticket Medio` reutiliza `Valor Total Gasto` e `Qtd Lotes Comprados`)

**Validação:** `Qtd Lotes Comprados` retornou **8.316** — batendo exatamente com o esperado após as correções do projeto (8.780 originais − 464 casos de dupla venda removidos no Dia 11).

## 2. Página de Visão Geral (overview) — medidas âncora do projeto

Antes de detalhar cada bloco de perguntas, criada uma primeira página de dashboard com cards resumindo os principais números do projeto:

```dax
Total Lotes Ofertados = COUNTROWS(lote)

Total Vendidos = 
COUNTROWS(FILTER(lote, NOT(ISBLANK(lote[id_arrematante]))))

Total Nao Vendidos = 
COUNTROWS(FILTER(lote, ISBLANK(lote[id_arrematante])))

Taxa de Conversao = 
DIVIDE([Total Vendidos], [Total Lotes Ofertados])

Total Leiloeiros = COUNTROWS(leiloeiro)

Total Processos = COUNTROWS(processo)

Valor Total Movimentado = 
SUMX(
    FILTER(lote, NOT(ISBLANK(lote[id_arrematante]))),
    lote[valor_lance_final]
)
```

### Discussão sobre o contexto de cada medida
Levantada uma reflexão importante sobre o que cada medida realmente representa:
- `Total Vendidos`, `Valor Total Movimentado`: filtram por `lote`, refletindo apenas o que foi efetivamente vendido — sensíveis a filtros de contexto (ano, estado, etc.)
- `Total Leiloeiros` e `Total Processos`: contam **diretamente nas tabelas dimensão** (`leiloeiro`, `processo`), sem passar por `lote` — ou seja, contam **todos os cadastrados**, mesmo que algum leiloeiro específico não tenha vendido nada ou nenhum processo tenha gerado uma venda. Isso é diferente de contar apenas "leiloeiros/processos com pelo menos uma venda".

**Pendência registrada para retomar na página exclusiva de leiloeiros:** decidir entre uma versão "cadastrados" (`COUNTROWS(leiloeiro)`) e uma versão "ativos" (baseada em vendas efetivas via `lote`/`leilao`) para a medida de contagem de leiloeiros, no contexto da análise de desempenho.

## 3. Bug identificado: `DISTINCTCOUNT` e valores `BLANK()`

### Medida inicial (com problema)
```dax
Total Arrematantes = DISTINCTCOUNT(lote[id_arrematante])
```
Resultado obtido: **244** — um a mais que o valor validado desde o Dia 1 do projeto (**243**).

### Causa identificada
Diferente do SQL, onde `COUNT(DISTINCT coluna)` ignora automaticamente valores `NULL`, o `DISTINCTCOUNT()` do DAX **conta `BLANK()` (vazio) como um valor distinto válido** dentro da contagem — todos os 26.982 lotes não vendidos (`id_arrematante` vazio) foram agrupados e contados coletivamente como "mais um arrematante", inflando o total em exatamente +1.

### Correção aplicada
```dax
Total Arrematantes = 
CALCULATE(
    DISTINCTCOUNT(lote[id_arrematante]),
    NOT(ISBLANK(lote[id_arrematante]))
)
```
Validado: retornou **243**, batendo com o valor de referência do projeto.

**Lição registrada:** sempre que usar `DISTINCTCOUNT()` em DAX sobre uma coluna que pode conter valores vazios, filtrar os `BLANK()` explicitamente (via `CALCULATE` + `NOT(ISBLANK(...))`, ou `FILTER`) antes de contar — comportamento diferente do `COUNT(DISTINCT ...)` em SQL, ao qual o autor do projeto já estava habituado.

## 4. Status do dashboard de overview (validado)

| Medida | Valor | Status |
|---|---|---|
| Total Lotes Ofertados | 35.298 | ✅ |
| Total Vendidos | 8.316 | ✅ |
| Taxa de Conversão | 23,56% | ✅ |
| Valor Total Movimentado | R$ 2,95 Bi | ✅ |
| Total Arrematantes | 243 | ✅ (corrigido) |
| Total Leiloeiros | 15 | ✅ (versão "cadastrados") |
| Total Processos | 9.882 | ✅ |
| Total Não Vendidos | 26.982 | ✅ |

*Nota: a Taxa de Conversão (23,56%) é ligeiramente menor que os ~24,9% observados nas análises SQL anteriores ao Dia 11 — reflete corretamente a base já livre dos 464 casos de dupla venda corrigidos naquele dia.*

## Próximos passos
- Testar as medidas do Bloco 4 num visual de tabela (nome + as três medidas), comparando com o ranking já validado em SQL (Renata Gouveia em quantidade, Mateus Loureiro em valor total, Douglas Amorim em ticket médio)
- Seguir construindo as medidas DAX para os demais blocos de perguntas

---

*Documento gerado como registro do progresso do projeto de normalização do banco de dados de leilão fictício.*


## DIA 16 (13,14 e 15/08)
Continuação Item 3 – 
	Modelagem de Base no Power BI
	Chave de Rastreabilidade (Coluna Calculada):
	Chave_Bem = fLeilao[processo_origem] & "-" & fLeilao[lote_origem] & "-" & fLeilao[sublote_origem]
	Relacionamentos Aplicados:
	dLote[id_lote] (1) → fLeilao[id_lote] (*)
	dPraca[Id_praca] (1) → fLeilao[Id_praca] (*)

Detalhamento das Perguntas (1 a 8)

1. Pergunta 1: Qual o volume total de lotes ofertados e arrematados?
	Medidas DAX:
	Total Lotes Ofertados = COUNTROWS(fLeilao)
	Total Lotes Vendidos = CALCULATE(COUNTROWS(fLeilao), NOT(ISBLANK(fLeilao[id_arrematante])))
	Relacionamento/Ajuste no Power BI:
	Cardinalidade 1:N ativada entre dLote e fLeilao garantindo a contagem correta dos lotes sem duplicação do cadastro base.

2. Pergunta 2: Qual a taxa de conversão geral de vendas?
	Medida DAX:
	Taxa Conversao % = DIVIDE([Total Lotes Vendidos], [Total Lotes Ofertados], 0)
	Relacionamento/Ajuste no Power BI:
	Tratamento de divisão por zero via função DIVIDE para evitar erros em visuais com filtros sem ofertas.

3. Pergunta 3: Qual o volume e taxa de conversão na 1ª Praça?
	Medidas DAX:
	Lotes Vendidos 1ª Praca = CALCULATE([Total Lotes Vendidos], dPraca[numero_praca] = 1)
	Taxa Conversao 1ª Praca % = DIVIDE([Lotes Vendidos 1ª Praca], CALCULATE([Total Lotes Ofertados], dPraca[numero_praca] = 1), 0)
	Relacionamento/Ajuste no Power BI:
	Filtro propagado a partir da dimensão dPraca via relacionamento ativo com fLeilao.

4. Pergunta 4: Qual o volume e taxa de conversão na 2ª Praça?
	Medidas DAX:
	Lotes Vendidos 2ª Praca = CALCULATE([Total Lotes Vendidos], dPraca[numero_praca] = 2)
	Taxa Conversao 2ª Praca % = DIVIDE([Lotes Vendidos 2ª Praca], CALCULATE([Total Lotes Ofertados], dPraca[numero_praca] = 2), 0)
	Relacionamento/Ajuste no Power BI:
	Filtro propagado pela tabela dPraca.

5. Pergunta 5: Qual o valor total arrecadado (arrematado)?
	Medida DAX:
	Total Valor Arrematado = SUM(fLeilao[valor_arrematado])
	Relacionamento/Ajuste no Power BI:
	Coluna valor_arrematado configurada como tipo de dado decimal/moeda na fLeilao.

6. Pergunta 6: Qual o ticket médio das arrematações?
	Medida DAX:
	Ticket Medio Arremate = AVERAGE(fLeilao[valor_arrematado])
	(Ou alternativamente: DIVIDE([Total Valor Arrematado], [Total Lotes Vendidos], 0))
	Relacionamento/Ajuste no Power BI:
	Média calculada desconsiderando registros onde não houve arremate (valores em branco/nulos).

7. Pergunta 7: Qual o valor total das comissões dos leiloeiros?
	Medida DAX:
	Total Comissão Leiloeiros = [Total Valor Arrematado] * 0.05
	Relacionamento/Ajuste no Power BI:
	Aplicação direta do percentual padrão de 5% sobre a medida consolidada de valor arrematado.

8. Pergunta 8: Qual a média e a soma do valor inicial ofertado?
	Medidas DAX:
	Total Valor Inicial = SUM(fLeilao[valor_inicial])
	Media Valor Inicial = AVERAGE(fLeilao[valor_inicial])
	Relacionamento/Ajuste no Power BI:
	Métricas baseadas na tabela fato fLeilao sem necessidade de contexto externo de filtro.

