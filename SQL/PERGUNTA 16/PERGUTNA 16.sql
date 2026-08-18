-- PERGUNTA 16 - 

-- Query simplificada

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
/*
Query 2 (agregada, 1 linha só)

Traz só a média geral — é a resposta direta pra pergunta "qual o deságio médio?", pronta pra reportar como um número único
*/


-- Query 1 (detalhada, 15.121 linhas)
SELECT
    l1.processo_origem,
    l1.lote_origem,
    l1.sublote_origem,
    l1.valor_inicial AS valor_1a_praca,
    l2.valor_inicial AS valor_2a_praca,
    ROUND((l1.valor_inicial - l2.valor_inicial) / l1.valor_inicial * 100, 2) AS desagio_percentual
FROM lote l1
JOIN leilao le1 ON le1.id_lote = l1.id_lote
JOIN praca p1 ON p1.Id_praca = le1.Id_praca AND p1.numero_praca = 1
JOIN lote l2
    ON l2.processo_origem = l1.processo_origem
    AND l2.lote_origem = l1.lote_origem
    AND l2.sublote_origem = l1.sublote_origem
JOIN leilao le2 ON le2.id_lote = l2.id_lote
JOIN praca p2 ON p2.Id_praca = le2.Id_praca AND p2.numero_praca = 2;
/*
Traz um deságio por item (cada linha é um bem específico). Use essa quando quiser:

Analisar a distribuição completa (histograma, ver se existem itens com deságio muito acima/abaixo da média)
Levar pro Power BI como base de dados (lá você calcula médias, filtros, segmentações interativas — é sempre melhor exportar o detalhe e deixar o BI agregar, do que já mandar só o resumo pronto)
*/
SELECT
    l1.processo_origem,
    l1.lote_origem,
    l1.sublote_origem,
    l1.valor_inicial AS valor_1a_praca,
    l2.valor_inicial AS valor_2a_praca,
    ROUND((l1.valor_inicial - l2.valor_inicial) / l1.valor_inicial * 100, 2) AS desagio_percentual
FROM lote l1
JOIN leilao le1 ON le1.id_lote = l1.id_lote
JOIN praca p1 ON p1.Id_praca = le1.Id_praca AND p1.numero_praca = 1
JOIN lote l2
    ON l2.processo_origem = l1.processo_origem
    AND l2.lote_origem = l1.lote_origem
    AND l2.sublote_origem = l1.sublote_origem
JOIN leilao le2 ON le2.id_lote = l2.id_lote
JOIN praca p2 ON p2.Id_praca = le2.Id_praca AND p2.numero_praca = 2;

/*
Insight da Pergunta 16 (finalmente respondida! 🎉)

Em média, quando um bem não vende na 1ª praça, seu valor de abertura cai 20,17% para a 2ª tentativa.

Comparando com o que você mencionou sobre a realidade de mercado

Você comentou que, na prática real, o desconto costuma ser de 40-50% entre 1ª e 2ª praça — bem maior que os 20,17% que encontramos aqui. Isso é coerente com o que já identificamos no Dia 10: os dados são fictícios e não foram desenhados pra replicar esse padrão específico de mercado. Vale registrar isso como mais um ponto de ajuste de realismo para a próxima geração de dados (junto com a pendência já registrada sobre a proporção de vendas em 2ª praça).

Cruzando com a Pergunta 4 (ágio médio, 15,01%)

Interessante comparar os dois números que já temos:

Deságio entre praças: -20,17% (o valor de abertura cai da 1ª pra 2ª tentativa)
Ágio por disputa: +15,01% (o valor de venda sobe em relação ao valor de abertura, dentro de uma mesma praça)

Isso sugere que, mesmo com o desconto de 20% na 2ª praça, a disputa entre arrematantes (ágio de ~15%) não recupera totalmente essa perda de valor de abertura — ou seja, o valor final de venda na 2ª praça tende a ficar, em média, ainda abaixo do valor de abertura da 1ª praça original (fazendo uma conta aproximada: 100 → 79,83 (deságio) → 91,80 (com ágio de 15%) — ainda uns 8% abaixo do valor inicial da 1ª praça).


*/