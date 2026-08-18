-- PERGUNTA 17 - quantos dias se passam entre a abertura da 1ª tentativa e a data em que o item efetivamente vendeu.

SELECT
    l1.processo_origem,
    l1.lote_origem,
    l1.sublote_origem,
    p1.data_abertura AS data_abertura_1a_praca,
    CASE
        WHEN l1.id_arrematante IS NOT NULL THEN p1.data_fechamento
        ELSE p2.data_fechamento
    END AS data_venda_efetiva,
    DATEDIFF(
        CASE
            WHEN l1.id_arrematante IS NOT NULL THEN p1.data_fechamento
            ELSE p2.data_fechamento
        END,
        p1.data_abertura
    ) AS dias_ate_venda
FROM lote l1
JOIN leilao le1 ON le1.id_lote = l1.id_lote
JOIN praca p1 ON p1.Id_praca = le1.Id_praca AND p1.numero_praca = 1
LEFT JOIN lote l2
    ON l2.processo_origem = l1.processo_origem
    AND l2.lote_origem = l1.lote_origem
    AND l2.sublote_origem = l1.sublote_origem
LEFT JOIN leilao le2 ON le2.id_lote = l2.id_lote
LEFT JOIN praca p2 ON p2.Id_praca = le2.Id_praca AND p2.numero_praca = 2
WHERE l1.id_arrematante IS NOT NULL  -- vendeu na 1ª praça
   OR l2.id_arrematante IS NOT NULL; -- ou vendeu na 2ª praça

/*
O que tem de novo:
DATEDIFF(data_fim, data_inicio) — função do MySQL que calcula a diferença em dias entre duas datas
LEFT JOIN (não JOIN) pra l2/le2/p2 — porque nem todo item teve uma 2ª praça (só quem não vendeu na 1ª); usar JOIN normal excluiria todos os itens vendidos já na 1ª tentativa
CASE WHEN — decide de qual praça pegar a data de venda, dependendo de onde o item efetivamente vendeu
*/


-- QUERY PRINCIPAL Antes de rodar a query detalhada, vamos direto pra uma versão agregada (média geral), já que é isso que queremos como resposta principal:
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
    AND l2.id_lote != l1.id_lote
LEFT JOIN leilao le2 ON le2.id_lote = l2.id_lote
LEFT JOIN praca p2 ON p2.Id_praca = le2.Id_praca AND p2.numero_praca = 2
WHERE l1.id_arrematante IS NOT NULL
   OR l2.id_arrematante IS NOT NULL;
   
   /*
   Insight final da Pergunta 17 🎉

Em média, um item leva 13,2 dias desde a abertura da 1ª praça até ser efetivamente vendido, considerando os 8.219 itens que de fato venderam (na 1ª ou na 2ª tentativa), com a base de dados agora livre da inconsistência de "dupla venda".

Cruzando com outras perguntas já respondidas

13,2 dias é um prazo relativamente curto — bate com a ideia de que, apesar do processo judicial ser burocrático, a janela entre a abertura de uma sessão de praça e seu encerramento costuma ser definida em poucos dias (compatível com editais que estabelecem prazos curtos de disputa).
   
   */