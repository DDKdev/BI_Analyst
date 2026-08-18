-- Pergunta 2 - Qual o valor total gasto por cada arrematante, do maior para o menor?

SELECT
    a.id_arrematante,
    a.nome,
    ROUND(sum(l.valor_lance_final),2) AS total_gasto
FROM arrematante a
JOIN lote l ON l.id_arrematante = a.id_arrematante
GROUP BY a.id_arrematante, a.nome
ORDER BY total_gasto DESC;

-- query para confirmar a quantidade total de arrematantes DISTINTOS que já compraram pelo menso 1 lote
SELECT COUNT(*) FROM (
    SELECT a.id_arrematante
    FROM arrematante a
    JOIN lote l ON l.id_arrematante = a.id_arrematante
    GROUP BY a.id_arrematante
) AS sub;

/* Explicação primeira QUERY
	Usamos SUM que é a função que retorna a soam total e ROUND para arredondar o resultado para 2 casas decimais
	ROUND(..., 2) — como estamos somando valores monetários (DECIMAL/FLOAT), às vezes a soma pode gerar casas decimais "sujas" 
    (tipo 15234.999999 por causa de arredondamento de ponto flutuante). 
    Arredondar pra 2 casas deixa o valor limpo e correto pra exibição.
*/

-- Mateus Loureiro que foi o TOP 1 arrematou R$'23.705.895.95' confirmado no Arquivo base CSV.
