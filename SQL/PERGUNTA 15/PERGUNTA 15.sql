/*
Pergunta 15 (Bloco 6 — última pergunta do bloco original)

O dia da semana da praça influencia no resultado (taxa de venda)?

Boa notícia: você já tem a coluna pronta pra isso — dia_semana, que está na tabela praca (lembra que resolvemos a ambiguidade dela lá no Dia 1/2, criando numero_praca?).

Caminho sugerido
Mesmo esqueleto da pergunta anterior, só trocando MONTH(p.data_fechamento) por p.dia_semana diretamente (já é uma coluna de texto, não precisa de função pra extrair nada)
Cuidado com a ordenação: dia da semana em texto ('segunda-feira', 'terça-feira'...) não ordena naturalmente em ordem cronológica só com ORDER BY simples — isso é um detalhe a pensar

*/
SELECT
    p.dia_semana,
    COUNT(*) AS total_ofertado,
    SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) AS total_vendido,
    ROUND(
        SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) * 100,
        2
    ) AS taxa_venda_percentual
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN praca p ON p.Id_praca = le.Id_praca
GROUP BY p.dia_semana
ORDER BY
    FIELD(p.dia_semana, 'domingo', 'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado');



/*
O que tem de novo:

ORDER BY FIELD(coluna, valor1, valor2, ...) — essa é a solução pro problema que te adiantei. Como dia_semana é uma coluna de texto (VARCHAR), um ORDER BY p.dia_semana comum ordenaria alfabeticamente (ex: "domingo" viria antes de "quarta-feira", que viria antes de "quinta-feira"...) — o que não faz sentido cronológico nenhum.

A função FIELD() resolve isso permitindo definir uma ordem customizada: você lista os valores na sequência que quer (domingo, segunda, terça...), e o MySQL ordena o resultado seguindo exatamente essa lista, em vez da ordem alfabética padrão.

⚠️ Atenção: confirme se os valores de dia_semana no seu banco estão exatamente escritos assim ('segunda-feira', com acento e hífen) — se estiverem diferentes (ex: sem acento, ou só 'segunda'), a função FIELD() não vai reconhecer e vai jogar esses valores pro final da ordenação, sem erro nenhum (silenciosamente). Se der algo estranho na ordem, é o primeiro lugar a checar.


Antes de interpretar, vale conferir a soma: 1581+3488+5062+12777+5320+5463+1607 = 35.298 ✅ e 401+859+1271+3175+1336+1336+402 = 8.780 ✅. Bate certinho.

Insight da Pergunta 15

A taxa de conversão é praticamente uniforme entre os dias da semana — variando apenas de 24,46% (sexta-feira) a 25,36% (domingo), uma diferença de menos de 1 ponto percentual. Essa é a menor variação que vimos até agora entre todas as dimensões analisadas (mais estável até que categoria de lote e comarca).

O achado mais interessante não é a taxa — é o volume

Repare na coluna total_ofertado: quarta-feira concentra 12.777 lotes (36% do total de 35.298!) — um volume muito maior que qualquer outro dia. Os dias de fim de semana (domingo, sábado) têm volume baixíssimo em comparação (1.581 e 1.607).

Isso sugere que quarta-feira é, de longe, o dia preferencial de encerramento de praças no seu conjunto de dados — provavelmente uma convenção operacional do setor (meio de semana, dia útil "cheio", sem proximidade de feriados/fins de semana que possam atrapalhar a participação).

Conclusão de negócio

O dia da semana não influencia a taxa de sucesso da venda, mas influencia fortemente a escolha operacional de quando marcar o encerramento — o mercado se concentra em quarta-feira por convenção/praticidade, não porque ali a chance de vender seja maior (a taxa em quarta, 24,85%, é até levemente abaixo da média geral de ~24,9%).


*/