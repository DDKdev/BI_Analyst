/*
	Pergunta 14 (Bloco 6 — Sazonalidade)

Existe um "melhor mês" para vender (maior taxa de sucesso ou maior valor de venda)?

Aqui entra uma novidade: vamos precisar extrair o mês de uma data (data_fechamento, que já validamos como a data da venda) usando a função MONTH() do MySQL.

Caminho sugerido
Ligar lote → leilao → praca (pra pegar data_fechamento)
Extrair o mês com MONTH(p.data_fechamento)
Agrupar por mês, calculando taxa de venda (mesmo padrão de sempre) e/ou valor total vendido
*/

SELECT
    MONTH(p.data_fechamento) AS mes,
    COUNT(*) AS total_ofertado,
    SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) AS total_vendido,
    ROUND(
        SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) * 100,
        2
    ) AS taxa_venda_percentual,
    ROUND(SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN l.valor_lance_final ELSE 0 END), 2) AS valor_total_vendido
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN praca p ON p.Id_praca = le.Id_praca
GROUP BY MONTH(p.data_fechamento)
ORDER BY mes;


/*
Atenção para um detalhe ao analisar o resultado

Diferente das perguntas anteriores, aqui MONTH() agrupa todos os anos juntos no mesmo mês (ex: janeiro de 2015, 2019 e 2023 caem todos em "mês = 1"). Isso é proposital para essa pergunta (queremos ver o padrão sazonal recorrente, independente do ano), mas vale ter isso em mente na hora de interpretar.

O que tem de novo:
MONTH(p.data_fechamento) — função de data do MySQL que extrai só o número do mês (1 a 12) de uma coluna DATE. Usamos ela tanto no SELECT quanto no GROUP BY — precisa ser a mesma expressão nos dois lugares, senão o agrupamento não corresponde ao que está sendo exibido.
ORDER BY mes (não por taxa ou valor) — aqui faz mais sentido ordenar pela sequência natural do calendário (Jan, Fev, Mar...), pra facilitar a leitura de um padrão sazonal ao longo do ano, em vez de embaralhar por ranking.
Duas métricas juntas (taxa e valor) — trouxe as duas porque "melhor mês" pode significar coisas diferentes: mês com maior taxa de conversão (%) não é necessariamente o mês com maior valor movimentado (R$) — pode haver um mês com poucas vendas, mas de altíssimo valor unitário, por exemplo.

Insight da Pergunta 14

Vamos primeiro confirmar a soma pra garantir que nada se perdeu no agrupamento por mês:

Total ofertado: 2923+2755+3209+2988+3085+2921+3008+2925+2906+2847+2760+2971 = 35.298 ✅
Total vendido: 749+688+799+746+789+743+793+698+736+671+678+690 = 8.780 ✅

Perfeito, bate exatamente com os totais gerais já validados.

Leitura dos resultados

Taxa de conversão por mês:

Melhor	Taxa	Pior	Taxa
Julho (7)	26,36%	Dezembro (12)	23,22%

Diferença de 3,14 pontos percentuais entre o melhor e o pior mês — uma variação maior que a vista entre categorias de lote (Pergunta 5) e comarcas (Pergunta 11), e comparável à variação entre leiloeiros (Pergunta 7, 2,69 p.p.).

Padrão que chama atenção: fim de ano é mais fraco

Dezembro (23,22%), Outubro (23,57%) e Agosto (23,86%) formam os três meses de pior conversão. Dezembro fazendo sentido intuitivo — período de festas/recesso, menos atividade de mercado e possivelmente menos disputa por lotes. Já Julho liderando (26,36%) pode reflete o período de "meio de ano", sem grandes feriados prolongados, com mercado mais aquecido.

Valor total movimentado:

Maior: Março (R$ 284,9 milhões)
Menor: Novembro (R$ 228,0 milhões)

Repare que valor e taxa não seguem exatamente o mesmo padrão — Março tem o maior valor movimentado, mas taxa de conversão apenas mediana (24,90%). Isso sugere que em Março, embora a proporção de vendas não seja a melhor, os lotes vendidos tendem a ter valor unitário mais alto.

Conclusão de negócio

Existe sazonalidade real e não desprezível no mercado — o fim de ano (Out-Dez) consistentemente performa pior tanto em conversão quanto (parcialmente) em valor, sugerindo que estratégias de precificação/divulgação poderiam ser ajustadas nesse período, ou que o volume de oferta poderia ser reduzido para não "desperdiçar" tentativas em um mercado mais frio.



*/