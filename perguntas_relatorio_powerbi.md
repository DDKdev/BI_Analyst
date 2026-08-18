# Perguntas de negócio — Projeto BD Leilão

### Referência para construção do relatório no Power BI

Contexto: banco de dados fictício de leilões judiciais, com fins de aprendizado e portfólio. As perguntas abaixo foram pensadas para simular necessidades reais de quem opera/investe nesse mercado (leiloeiros, escritórios de advocacia, fundos de ativos judiciais, tribunais).

\---

## 1\. Eficiência do processo judicial (tempo e sucesso)

* Quanto tempo, em média, um lote leva desde a 1ª praça até ser vendido (ou desistir)?
* Qual a taxa de sucesso de venda na 1ª praça vs 2ª vs 3ª+ praça?
* Existe correlação entre número de praças necessárias e a comarca/tribunal responsável? Alguns cartórios são mais "eficientes" que outros?

## 2\. Comportamento do mercado / precificação

* Qual o deságio médio entre valor inicial e valor final de venda? Isso muda entre 1ª e 2ª praça?
* Existe correlação entre categoria do lote (imóvel, veículo, etc.) e velocidade/taxa de venda?
* Lotes com maior valor inicial demoram mais para vender, ou o contrário?
* **Qual o deságio real entre praças, para o mesmo lote físico?** Observação importante: não existe no modelo uma coluna de "valor de avaliação" do bem — `valor\_inicial` representa apenas o lance mínimo para abrir a disputa em cada praça, e pode já vir com desconto na 2ª praça (ou seguintes) em relação à 1ª, caso o lote não tenha tido licitantes na tentativa anterior. Para medir o deságio de fato, é necessário comparar o `valor\_inicial` do mesmo lote (mesmo bem físico, não a mesma linha de `lote`) entre praças diferentes — e não comparar `valor\_inicial` com `valor\_lance\_final` dentro da mesma praça, que mede ágio (valorização por disputa), não deságio.

## 3\. Performance de leiloeiros

* Qual leiloeiro tem a melhor taxa de conversão (lotes vendidos / lotes ofertados)?
* Ranking de leiloeiros por valor total arrecadado e por comissão gerada.

## 4\. Comportamento do arrematante (o "cliente")

* Existem arrematantes recorrentes (possíveis investidores profissionais, não pessoas físicas comuns)?
* Ticket médio por arrematante.
* Concentração: qual % do valor total arrematado é responsabilidade de uma pequena parcela de arrematantes (Pareto)?

## 5\. Geografia / distribuição regional

* Quais estados/regiões têm mais processos e maior valor movimentado?
* A taxa de sucesso de venda varia por região?

## 6\. Sazonalidade

* Existe um "melhor mês" para vender (maior taxa de sucesso ou maior valor de venda)?
* O dia da semana da praça influencia no resultado?

## 7\. Pendências técnicas — RESOLVIDAS EM 31/07/2026 (ver diário, Dia 11)

* **Pergunta 16 — Deságio real entre praças:** ✅ Respondida. Deságio médio de **20,17%** entre o valor inicial da 1ª e da 2ª praça (base: 15.121 itens que precisaram de 2ª tentativa). Abaixo do padrão real de mercado mencionado (\~40-50%) — ver pendência de realismo estatístico.
* **Pergunta 17 — Tempo até a venda:** ✅ Respondida. Média de **13,2 dias** entre a abertura da 1ª praça e a venda efetiva (base: 8.219 itens vendidos, após correção de uma inconsistência de "dupla venda" encontrada em 464 registros).

Resolvidas usando a chave `Processo + Lote + SubLote` (colunas `processo\_origem`, `lote\_origem`, `sublote\_origem` adicionadas a `lote`), que identifica o mesmo item físico através de diferentes tentativas de praça.

\---

## 

