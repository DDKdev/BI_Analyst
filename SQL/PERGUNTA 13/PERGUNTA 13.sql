/*
	Pergunta 13 (Bloco 5 — última do bloco)

A taxa de sucesso de venda varia por estado/região
*/

SELECT
    loc.Estado,
    COUNT(*) AS total_lotes_ofertados,
    SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) AS total_lotes_vendidos,
    ROUND(
        SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) * 100,
        2
    ) AS taxa_venda_percentual
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN processo pr ON pr.id_processo = le.id_processo
JOIN cartorio c ON c.Id_cartorio = pr.id_cartorio
JOIN localizacao loc ON loc.ID_local_cartorio = c.ID_local_cartorio
GROUP BY loc.Estado
ORDER BY taxa_venda_percentual DESC;

/*
O que mudou em relação à Pergunta 12

É basicamente a mesma estrutura, só que:

Removi COUNT(DISTINCT pr.id_processo) e valor_total_movimentado (não são necessários pra essa pergunta específica)
Adicionei o cálculo de taxa_venda_percentual, no mesmo padrão que já usamos nas Perguntas 5, 7 e 10 (SUM(CASE WHEN...) / COUNT(*) * 100)
Ordenei por taxa (não por volume), já que a pergunta é sobre eficiência de conversão, não volume de negócio

Insight final da Pergunta 13 (ajustado)

A "taxa de sucesso por estado" não é uma métrica independente neste modelo — ela é estruturalmente idêntica à taxa de conversão por leiloeiro (Pergunta 7), porque existe uma relação fixa de 1 leiloeiro por estado.

Isso muda a leitura de negócio: não dá pra dizer "o Ceará vende melhor que o Rio de Janeiro" como um fenômeno regional (custo de vida, perfil de comprador local, etc.) — o que está sendo medido, na verdade, é a performance individual do leiloeiro responsável por aquele estado. Se a Dalva fosse realocada para o Rio de Janeiro, a expectativa (dado esse desenho) seria a taxa "do RJ" mudar para acompanhar a taxa dela, não o contrário.

Vale como nota metodológica pro relatório

Essa é uma boa oportunidade de mostrar maturidade analítica no portfólio: em vez de apresentar as duas perguntas como insights separados, você pode registrar explicitamente que a granularidade real de análise nesse dataset é o leiloeiro, não o estado — e usar isso pra explicar por que não vale a pena investir em um gráfico geográfico (mapa) de taxa de conversão, já que ele só repetiria visualmente o que o ranking de leiloeiros já mostra.
*/