-- PERGUTNA 6 - Lotes com maior valor inicial demoram mais para vender, ou o contrário?

SELECT
    CASE
        WHEN l.valor_inicial < 50000 THEN 'Baixo (< 50k)'
        WHEN l.valor_inicial BETWEEN 50000 AND 200000 THEN 'Médio (50k-200k)'
        ELSE 'Alto (> 200k)'
    END AS faixa_valor_inicial,
    COUNT(*) AS qtd_lotes_vendidos,
    ROUND(AVG(p.numero_praca), 2) AS media_numero_praca
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN praca p ON p.Id_praca = le.Id_praca
WHERE l.id_arrematante IS NOT NULL
GROUP BY faixa_valor_inicial
ORDER BY media_numero_praca DESC;

/* O que essa query faz:
	CASE WHEN — cria 3 faixas de valor inicial (você pode ajustar os cortes depois de ver a distribuição real dos valores)
	JOIN duplo (lote → leilao → praca) — necessário porque numero_praca só existe em praca, e a ligação entre lote e praca passa por leilao
	WHERE l.id_arrematante IS NOT NULL — nosso critério já validado de "vendido"
	AVG(p.numero_praca) — a métrica central: quanto maior, mais tentativas em média foram necessárias pra vender lotes daquela faixa*/

/*
Insight da Pergunta 6

Existe uma leve tendência: quanto maior o valor inicial, menor o número médio 
de praças necessárias para vender.

Faixa               Praça média
Baixo (< 50k)       1,51
Médio (50k-200k)    1,45
Alto (> 200k)       1,42

Ou seja, lotes de menor valor demoram (ligeiramente) mais pra vender que lotes 
de maior valor — o oposto do que a intuição comum sugeriria ("bens caros são 
mais difíceis de vender").

Possível explicação (hipótese, não comprovada pelos dados)
Bens de maior valor inicial tendem a ser imóveis maiores/melhores localizados 
ou veículos de padrão superior, que podem atrair investidores profissionais 
com mais poder de compra (lembra dos "grandes arrematantes" que identificamos 
no Bloco 4) — enquanto bens de menor valor podem ser itens de nicho mais 
restrito, com menos gente disposta a competir por eles logo na 1ª tentativa.

Ressalva importante sobre o tamanho do efeito
A diferença entre as faixas é pequena (0,09 no intervalo de 1,42 a 1,51) — 
não é um efeito dramático. Vale reportar isso com cautela no relatório: 
existe uma tendência, mas é sutil, não uma regra forte.

Nota de revisão (31/07/2026)
Valores recalculados após correção da numeração de praça (891 casos de 
"praça única" órfã renumerados para 1ª praça, ver diário Dia 9). Resultado 
original, antes da correção: Baixo 1,60 / Médio 1,55 / Alto 1,52. A correção 
deslocou todas as faixas para baixo de forma proporcional (~0,09 a 0,10 cada), 
sem alterar a direção nem a magnitude relativa da tendência — a conclusão de 
negócio permanece a mesma.
*/