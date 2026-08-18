-- PERGUNTA 9 - Qual a concentração do valor total arrematado entre os arrematantes? Uma pequena parcela é responsável por qual percentual do total (lógica de Pareto)?

-- Versão simplificada (com LIMIT)
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
    -- Depois, calculamos o percentual manualmente: valor_top_10_pct / valor_total_geral * 100.

/* 
	Por que a query ficou assim (duas subconsultas independentes)
A primeira subconsulta agrupa por arrematante, ordena pelo maior gasto, e pega só os 24 primeiros (LIMIT 24) — depois soma o valor desses 24
A segunda subconsulta pega o total geral (todos os arrematantes, todos os lotes vendidos), sem LIMIT
Colocamos as duas lado a lado no mesmo SELECT só pra facilitar a leitura/comparação
*/

-- com o resultado da consulta efetuamos a conta manualmente Boa! Vamos calcular o percentual:
-- 456.532.129,17 ÷ 3.087.769.016,23 × 100 ≈ 14,78%
/*
	Insight da versão simplificada
Os 10% de arrematantes com maior gasto (24 de 243) são responsáveis por apenas ~14,78% do valor total arrecadado.
Isso é um resultado interessante — e possivelmente inesperado se você já vinha imaginando uma concentração forte (tipo "os 10% dominam 50% do mercado", que é comum em outros contextos). Aqui, a concentração é bem mais moderada que o clássico "efeito Pareto extremo" — sugere que o valor está relativamente bem distribuído entre os arrematantes, sem um grupo pequeno dominando desproporcionalmente o mercado.
Por que isso pode fazer sentido no seu domínio
Lembra que identificamos 3 perfis de comprador (alto volume, alto valor agregado, alto ticket unitário)? Como esses perfis são diferentes pessoas (não o mesmo grupo liderando em tudo), a concentração de valor acaba "diluída" entre perfis distintos, em vez de ficar concentrada num único grupo dominante.
*/