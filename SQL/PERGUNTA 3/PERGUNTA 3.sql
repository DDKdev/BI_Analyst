-- PERGUNTA 3 Qual o ticket médio (valor médio gasto por lote) de cada arrematante, do maior para o menor?
SELECT
    a.id_arrematante,
    a.nome,
    ROUND(AVG(l.valor_lance_final),2) AS ticket_medio
FROM arrematante a
JOIN lote l ON l.id_arrematante = a.id_arrematante
GROUP BY a.id_arrematante, a.nome
ORDER BY ticket_medio DESC;

-- query para confirmar a quantidade total de arrematantes DISTINTOS que já compraram pelo menso 1 lote
SELECT COUNT(*) FROM (
    SELECT a.id_arrematante
    FROM arrematante a
    JOIN lote l ON l.id_arrematante = a.id_arrematante
    GROUP BY a.id_arrematante
) AS sub;

/* Explicação primeira QUERY
	Usamos AVG que é a função que retorna a média e ROUND para arredondar o resultado para 2 casas decimais
	ROUND(..., 2) — como estamos somando valores monetários (DECIMAL/FLOAT), às vezes a soma pode gerar casas decimais "sujas" 
    (tipo 15234.999999 por causa de arredondamento de ponto flutuante). 
    Arredondar pra 2 casas deixa o valor limpo e correto pra exibição.
*/

-- Douglas AMorim que foi o TOP 1 de ticket médio, possui R$'581194,74' confirmado no Arquivo base CSV.
