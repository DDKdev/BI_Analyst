-- Quantos lotes cada arrematante comprou, do maior para o menor número de lotes?
SELECT
    a.id_arrematante,
    a.nome,
    COUNT(l.id_lote) AS qtd_lotes_comprados
FROM arrematante a
JOIN lote l ON l.id_arrematante = a.id_arrematante
GROUP BY a.id_arrematante, a.nome
ORDER BY qtd_lotes_comprados DESC;

-- qquery para confirmar a quantidade total de arrematantes DISTINTOS
SELECT COUNT(*) FROM (
    SELECT a.id_arrematante
    FROM arrematante a
    JOIN lote l ON l.id_arrematante = a.id_arrematante
    GROUP BY a.id_arrematante
) AS sub;

-- QUERY PARA VALIDAR QUE RENATA GOUVEIA ARREMATOU 55 LOTES
SELECT COUNT(*)
FROM leilao_bruto
WHERE Arrematante = 'Renata Gouveia';

/* Explicando a lógica PRIMEIRA QUERY:
JOIN (não LEFT JOIN) — aqui faz sentido usar JOIN normal, porque só queremos arrematantes que de fato compraram algo. Se algum arrematante estivesse cadastrado sem nenhum lote vinculado (não deveria acontecer no seu caso, já que a tabela só foi populada a partir de quem realmente arrematou), ele simplesmente não apareceria — o que é o comportamento certo aqui.
COUNT(l.id_lote) — conta quantas linhas de lote cada arrematante tem associada. Contamos l.id_lote (a chave da tabela lote) em vez de COUNT(*) só por boa prática — deixa explícito o que está sendo contado.
GROUP BY a.id_arrematante, a.nome — agrupamos por ambos porque, tecnicamente, o SQL exige que toda coluna no SELECT que não seja agregada (COUNT, SUM, etc.) apareça no GROUP BY. Como id_arrematante já é único, o nome "vem de graça" junto, mas colocamos os dois por segurança/clareza.
ORDER BY qtd_lotes_comprados DESC — ranking do maior comprador pro menor, como você pediu.
Resultado esperado

Uma lista com até 243 linhas (o total de arrematantes), mostrando quem comprou mais lotes no topo. Lembra que calculamos antes que a média é de ~36 lotes por arrematante — então esse ORDER BY vai te mostrar rapidinho quem são os "grandes compradores" (possíveis investidores profissionais) vs. quem comprou só 1 ou 2.*/

/* SEGUNDA QUERY
Vamos confirmar quantas linhas o resultado trouxe de verdade: RESULTADO ESPERADO: 243 */