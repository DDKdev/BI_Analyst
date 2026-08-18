-- PERGUNTA 4 Qual o ágio médio (valorização) entre o valor inicial (lance mínimo) e o valor final de venda?

use leilao
-- Descobrindo o ágio médio das vendas
SELECT
    ROUND(AVG((valor_lance_final - valor_inicial) / valor_inicial) * 100, 2) AS agio_medio_percentual
FROM lote
WHERE id_arrematante IS NOT NULL;
-- ↑ Filtro essencial: garante que só entram lotes REALMENTE VENDIDOS.
--   valor_lance_final sozinho não é suficiente como filtro, pois essa coluna
--   pode estar preenchida mesmo em lotes não vendidos (maior lance recebido,
--   mas insuficiente para arrematar). id_arrematante só é preenchido quando
--   existe, de fato, um comprador — é o critério correto de "venda concluída"
--   definido e validado no Dia 3 deste projeto.


/*Insight da Pergunta 4

O ágio médio dos lotes efetivamente vendidos é de 14,95%.

Isso significa que, na média, quando um lote é de fato arrematado, o valor final de venda supera o lance mínimo de abertura em cerca de 15% — evidenciando que existe disputa real entre arrematantes na maioria dos casos vendidos (não são vendas "sem concorrência", saindo exatamente pelo valor mínimo).

O que esse número não nos diz (limitação já identificada)

Como valor_inicial é apenas o lance mínimo (e não uma avaliação de mercado do bem), esse ágio de 15% não representa quanto o comprador "pagou a mais que o valor de mercado" — ele representa apenas a valorização dentro da disputa daquela praça específica. Essa é justamente a lacuna que motivou a nova pergunta que adicionamos (deságio real comparando o mesmo lote entre praças diferentes).

Achado metodológico relevante junto com essa pergunta

Descobrimos que valor_lance_final está preenchido em todos os 35.298 lotes (vendidos ou não), mas só 8.780 foram de fato arrematados. Isso é uma característica importante do dado bruto a se ter em mente para qualquer análise futura que envolva essa coluna — sempre filtrar por id_arrematante IS NOT NULL, nunca assumir que valor_lance_final IS NOT NULL equivale a "vendido". */