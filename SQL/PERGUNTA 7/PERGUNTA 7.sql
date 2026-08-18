-- PERGUNTA 7 - Qual leiloeiro tem a melhor taxa de conversão (lotes vendidos ÷ lotes ofertados)?

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

/*
Pontos de atenção pra sua revisão:
Ponto de partida: FROM leilao, não FROM lote — como id_leiloeiro só existe na tabela leilao (é lá que a informação "quem conduziu esse evento" está registrada), precisamos partir de leilao e trazer lote via JOIN, e não o contrário.
Apelidos (le para leilao, le_o para leiloeiro) — usei nomes diferentes de alias porque leilao e leiloeiro começam igual (le), e isso geraria ambiguidade/confusão se eu usasse l pra ambos. Vale conferir se ficou claro, ou se você prefere nomes mais explícitos (tipo lei e lor).
COUNT(*) aqui conta linhas de leilao, não de lote diretamente — como cada linha de leilao corresponde a exatamente um lote ofertado numa praça (relação 1:1 no seu modelo, lembra que confirmamos isso lá no Dia 1?), isso não deveria gerar diferença no resultado. Mas vale essa reflexão na sua revisão: será que COUNT(*) aqui está contando a mesma coisa que contaríamos se partíssemos de lote?
*/

-- VALIDAÇÃO
SELECT
    SUM(total) AS soma_ofertados,
    SUM(vendidos) AS soma_vendidos
FROM (
    SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) AS vendidos
    FROM leilao le
    JOIN lote l ON l.id_lote = le.id_lote
    JOIN leiloeiro le_o ON le_o.id_leiloeiro = le.id_leiloeiro
    GROUP BY le_o.id_leiloeiro
) AS sub;

/* 
validar se a soma de todos os leiloeiros bate com os totais gerais que já conhecemos (35.298 ofertados e 8.780 vendidos).
Esperado: soma_ofertados = 35298 e soma_vendidos = 8780.

Se bater exatamente com esses números, confirma duas coisas de uma vez:

Nenhuma linha de leilao ficou "órfã" (sem leiloeiro vinculado) e foi perdida no JOIN
A contagem COUNT(*) a partir de leilao realmente equivale à contagem a partir de lote (validando aquele ponto de atenção que te passei antes, sobre a relação 1:1)*/


/* Insight da Pergunta 7

Existe uma diferença real, ainda que moderada, na taxa de conversão entre leiloeiros.

Posição	Leiloeiro	Taxa de conversão
1º	Dalva	26,44%
2º	Renan	25,98%
...	...	...
14º	Paula	24,03%
15º	Márcia	23,75%

A diferença entre o melhor (Dalva, 26,44%) e o pior (Márcia, 23,75%) é de 2,69 pontos percentuais — um intervalo mais expressivo que o que vimos entre categorias de lote (que variava menos de 0,15 p.p.). Isso sugere que o leiloeiro responsável pode, de fato, ter alguma influência na taxa de sucesso de venda — seja por qualidade de divulgação, condução do leilão, ou até pelo perfil dos lotes que cada um tende a receber (o que ainda não sabemos se é aleatório ou não).

Ponto de atenção para não superinterpretar

Repare que o volume de lotes ofertados varia bastante entre eles (de 720 com Genivaldo a 4.416 com Antonio) — leiloeiros com poucos lotes ofertados (Renan, 762; Genivaldo, 720) podem ter sua taxa mais sujeita a "sorte"/variação estatística do que os que têm milhares de lotes (Antonio, Márcia, Paula). Vale ter essa ressalva no relatório final: os números com menor volume têm uma margem de incerteza maior.
*/