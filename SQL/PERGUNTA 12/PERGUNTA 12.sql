/*
Pergunta 12 (Bloco 5 — Geografia)

Quais estados/regiões têm mais processos e maior valor movimentado?

Duas métricas aqui: (1) quantidade de processos por estado, e (2) valor total movimentado (vendido) por estado.

Caminho sugerido
A coluna Estado está em cartorio (lembra, veio de localizacao... não, espera — Estado ficou em localizacao, e cartorio se liga a ela via ID_local_cartorio)
Caminho: lote → leilao → processo → cartorio → localizacao (pra pegar Estado)
Contar processos distintos por estado, e somar valor vendido por estado
*/

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

/*
O que tem de novo nessa query:
COUNT(DISTINCT pr.id_processo) — como cada processo pode ter vários lotes (um mesmo processo judicial pode leiloar múltiplos bens), contar COUNT(*) contaria processos repetidos. O DISTINCT garante que cada processo seja contado só uma vez, mesmo aparecendo em várias linhas.
SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN l.valor_lance_final ELSE 0 END) — essa é uma variação do CASE WHEN que já usamos antes (nas Perguntas 5, 7 e 10), mas em vez de contar 1/0, agora somamos o valor só quando a condição é verdadeira, e 0 caso contrário. Isso é equivalente a fazer SUM(valor) WHERE id_arrematante IS NOT NULL, mas permite calcular junto com as outras métricas (como qtd_processos e total_lotes_ofertados) numa única passada pelos dados, sem precisar de subconsulta separada.
Cinco tabelas na cadeia (lote → leilao → processo → cartorio → localizacao) — o encadeamento mais longo até agora, mas segue o mesmo princípio: cada JOIN só "acrescenta mais um elo" até chegar na informação que você precisa (Estado).


Resultado claro e bem organizado — 14 estados, ordenados por valor movimentado.

Insight da Pergunta 12

São Paulo lidera com folga absoluta em todas as métricas: 1.707 processos, 6.054 lotes ofertados, 1.498 vendidos, e R$ 537,2 milhões movimentados — praticamente 50% a mais que o 2º colocado (Minas Gerais, R$ 359,8 milhões).

Padrão geral: forte correlação entre volume e valor

Os estados no topo em valor (SP, MG, RJ, SC, RS) são também os que têm mais processos e mais lotes ofertados — não há nenhuma "surpresa" de um estado pequeno gerando valor desproporcional. Isso sugere que o mercado de leilão judicial nesse conjunto de dados é proporcional ao tamanho/atividade judicial de cada estado, sem estados "premium" que fujam do padrão.

Um agrupamento natural em 3 faixas
Faixa	Estados	Característica
Grande porte	SP, MG, RJ	Acima de R$ 300 milhões, mais de 1.000 processos
Médio porte	SC, RS, MS, CE, PE, GO, BA, AM	Entre R$ 170-280 milhões
Menor porte	ES, AP, PA	Abaixo de R$ 72 milhões, poucos processos (~200-230)
*/