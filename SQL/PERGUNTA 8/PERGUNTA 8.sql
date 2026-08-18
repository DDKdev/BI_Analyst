-- PERGUNTA 8 - Ranking de leiloeiros por valor total arrecadado e por comissão gerada.

SELECT
    le_o.id_leiloeiro,
    le_o.nome,
    ROUND(SUM(l.valor_lance_final), 2) AS valor_total_arrecadado,
    ROUND(SUM(l.comissao_leiloeiro), 2) AS comissao_total_gerada
FROM leilao le
JOIN lote l ON l.id_lote = le.id_lote
JOIN leiloeiro le_o ON le_o.id_leiloeiro = le.id_leiloeiro
WHERE l.id_arrematante IS NOT NULL
GROUP BY le_o.id_leiloeiro, le_o.nome
ORDER BY valor_total_arrecadado DESC;

/*
	Pontos de atenção pra sua revisão:
WHERE l.id_arrematante IS NOT NULL — essencial aqui, e ainda mais crítico que nas perguntas anteriores. Lembra que valor_lance_final e comissao_leiloeiro estão preenchidos em todos os 35.298 lotes, vendidos ou não? Sem esse filtro, estaríamos somando valores de lotes que nunca foram efetivamente arrematados, inflando tanto o "valor arrecadado" quanto a "comissão" de forma incorreta.
Duas somas na mesma query — como as duas métricas vêm de colunas diferentes da mesma tabela (lote), dá pra calcular ambas numa única passada, sem precisar de duas queries separadas.
ORDER BY valor_total_arrecadado — ordenei pelo valor arrecadado, mas repare que o ranking por comissão pode vir diferente (já que comissao_leiloeiro é geralmente um percentual do valor, mas talvez com taxas diferentes por leiloeiro/negociação) — vale conferir isso na sua revisão, comparando as duas colunas lado a lado no resultado.
*/

-- VALIDAÇÃO - COMPARAÇÃO ENTRE OS DOIS RESULTADOS: DEVEM SER EXATAMENTE IGUAIS
-- 	3.087.769.016,23 E 	149.568.522,30

-- 1° Soma agrupada por leiloeiro (o que a query de ranking gera)
SELECT
    SUM(valor_total) AS soma_valor_arrecadado,
    SUM(comissao_total) AS soma_comissao
FROM (
    SELECT
        SUM(l.valor_lance_final) AS valor_total,
        SUM(l.comissao_leiloeiro) AS comissao_total
    FROM leilao le
    JOIN lote l ON l.id_lote = le.id_lote
    JOIN leiloeiro le_o ON le_o.id_leiloeiro = le.id_leiloeiro
    WHERE l.id_arrematante IS NOT NULL
    GROUP BY le_o.id_leiloeiro
) AS sub;

-- 2° -- Soma direta na tabela lote, sem JOIN nenhum, só pra comparar 
SELECT
    ROUND(SUM(valor_lance_final), 2) AS soma_valor_direto,
    ROUND(SUM(comissao_leiloeiro), 2) AS soma_comissao_direto
FROM lote
WHERE id_arrematante IS NOT NULL;


/*
	Agora sim, temos o ranking completo. Vamos aos insights:

Insight da Pergunta 8

Antonio lidera com folga: R$ 359,8 milhões arrecadados e R$ 17,5 milhões em comissão — bem acima do 2º colocado (Márcia, R$ 304,2 milhões).

Cruzando com a Pergunta 7 (taxa de conversão) — o achado mais interessante

Repare numa inversão curiosa: Dalva, que tinha a melhor taxa de conversão (26,44%, 1º lugar na Pergunta 7), aparece apenas em 8º lugar em valor arrecadado. Já Antonio, que tinha uma taxa de conversão mediana (24,41%, 11º lugar na Pergunta 7), lidera disparado em valor arrecadado.

Isso faz todo sentido quando cruzamos com o volume: lembra que Antonio tinha o maior número de lotes ofertados (4.416, quase o dobro de muitos outros)? Ou seja, Antonio não é o mais eficiente (proporcionalmente), mas é o que mais movimenta em volume absoluto — provavelmente por ter uma carteira de leilões maior, não por ser "melhor" leiloeiro.

Relação consistente entre valor arrecadado e comissão

A comissão parece ser uma fração praticamente fixa do valor arrecadado (~4,8-4,9% em todos os casos, conferindo rapidamente: 17.543.435 / 359.838.540 ≈ 4,88%; 2.780.539 / 57.419.108 ≈ 4,84%). Isso sugere que a taxa de comissão é padronizada no mercado (ou pelo menos neste conjunto de dados), não negociada individualmente por leiloeiro.

Conclusão prática pro relatório

Essa pergunta, combinada com a Pergunta 7, revela que "volume de negócios" e "eficiência de conversão" são métricas independentes — um leiloeiro pode ser eficiente proporcionalmente (Dalva) sem necessariamente ser o que mais fatura (Antonio), e vice-versa. Isso é uma ótima dupla de gráficos pro Power BI: um ranking de valor absoluto ao lado de um ranking de taxa de conversão, mostrando que são histórias diferentes.
*/