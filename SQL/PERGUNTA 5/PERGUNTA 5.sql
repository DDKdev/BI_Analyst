--  PERGUNTA 5 - Existe correlação entre a categoria do lote e a taxa de venda?

-- Insight consolidado da Pergunta 5
	-- Não existe diferença relevante na taxa de venda entre as categorias de lote (Móveis 24,95%, Automóveis 24,87%, Imóveis 24,81% — uma variação de menos de 0,15 pontos percentuais entre elas). Isso sugere que, neste conjunto de dados, a categoria do bem não é um fator determinante para a probabilidade de arrematação — o que é um achado interessante, pois contraria a hipótese intuitiva de que bens de maior complexidade/valor (como imóveis) teriam mais dificuldade de venda que bens mais "líquidos" (como automóveis).
	-- m detalhe que vale registrar
	-- A taxa geral de venda gira em torno de ~25% — ou seja, apenas 1 em cada 4 lotes ofertados é efetivamente arrematado. Isso bate com a proporção que já conhecíamos (8.780 vendidos ÷ 35.298 ofertados ≈ 24,9%), e reforça que esse patamar de ~25% parece ser uma característica estrutural do mercado de leilão judicial em geral, não algo que varia por tipo de bem.

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

-- teste de validação
SELECT SUM(total) as soma_ofertados, SUM(vendidos) as soma_vendidos
FROM (
    SELECT COUNT(*) AS total, 
           SUM(CASE WHEN id_arrematante IS NOT NULL THEN 1 ELSE 0 END) AS vendidos
    FROM lote
    GROUP BY categoria
) AS sub;

-- Esperado: soma_ofertados = 35.298 e soma_vendidos = 8.780 (os mesmos números que já validamos antes). 
-- Se bater, confirma que não perdemos nenhuma linha no agrupamento por categoria (por exemplo, 
	-- categorias NULL ou mal escritas que ficassem de fora sem você perceber).


-- Explicação da query
-- COUNT(*) — conta o total de linhas (lotes ofertados) dentro de cada categoria, independente de terem vendido ou não.
-- SUM(CASE WHEN id_arrematante IS NOT NULL THEN 1 ELSE 0 END) — esse é o "truque" mais importante da query. O CASE WHEN funciona como um IF: pra cada linha, se id_arrematante não for nulo (ou seja, foi vendido), ele retorna 1; caso contrário, retorna 0. O SUM() em volta soma esses 1s e 0s, resultando na contagem condicional de quantos foram vendidos — sem precisar de uma segunda query ou subconsulta.
-- Divisão dos dois (vendidos / total * 100) — calcula o percentual de sucesso de venda daquela categoria.
-- GROUP BY categoria — agrupa tudo por categoria, gerando uma linha de resultado por tipo de bem.
-- ORDER BY taxa_venda_percentual DESC — mostra primeiro as categorias com maior taxa de sucesso.
-- Por que usar CASE WHEN em vez de um segundo WHERE/subquery

-- Se você tentasse usar WHERE id_arrematante IS NOT NULL direto na query, perderia a contagem do total ofertado (porque o WHERE filtraria as linhas antes de agrupar, sobrando só os vendidos). O CASE WHEN dentro do SUM permite calcular as duas métricas (total e vendidos) na mesma passada pelos dados, sem precisar rodar duas queries separadas ou fazer um JOIN complicado.