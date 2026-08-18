/*
PERGUNTA 11 - Existe correlação entre o número de praças necessárias para vender e a comarca/cartório responsável? Alguns cartórios são "mais eficientes" (vendem mais rápido) que outros?

Caminho sugerido
Ligar lote → leilao → processo → cartorio (pra pegar a comarca)
Ligar também lote → leilao → praca (pra pegar o numero_praca)
Filtrar só lotes vendidos (já sabe o critério)
Agrupar por comarca, calculando a média de numero_praca (quanto menor, mais "eficiente"/rápido pra vender)
Bônus: também vale contar quantos lotes cada comarca teve, pra saber se o resultado é confiável (comarca com poucos lotes vendidos pode ter média enganosa)
*/

SELECT
    c.comarca,
    COUNT(*) AS total_lotes_vendidos,
    ROUND(AVG(p.numero_praca), 2) AS media_numero_praca
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN processo pr ON pr.id_processo = le.id_processo
JOIN cartorio c ON c.Id_cartorio = pr.id_cartorio
JOIN praca p ON p.Id_praca = le.Id_praca
WHERE l.id_arrematante IS NOT NULL
GROUP BY c.comarca
ORDER BY media_numero_praca ASC;

/*
	O que muda em relação às queries anteriores:
Quatro JOINs em cadeia — esse é o encadeamento mais longo até agora: lote → leilao → processo → cartorio (pra chegar na comarca), e mais um JOIN separado leilao → praca (pra pegar o número da praça). Repare que os dois caminhos (processo→cartorio e praca) partem os dois de leilao, não um do outro — são "ramificações" independentes a partir da mesma tabela central.
WHERE l.id_arrematante IS NOT NULL — filtro de sempre, garantindo que só olhamos pra vendas efetivamente concluídas (senão a "eficiência" ficaria distorcida por lotes que nunca venderam).
ORDER BY media_numero_praca ASC (crescente, não DESC) — aqui o "melhor" resultado é o menor número de praça médio (vendeu mais rápido), então faz sentido ordenar do mais eficiente pro menos eficiente.
COUNT(*) AS total_lotes_vendidos — incluí de propósito, seguindo a dica que te dei antes: sem isso, você corre risco de olhar pra uma comarca com média muito baixa (parecendo super eficiente), mas que teve só 2-3 vendas — não é uma amostra confiável pra tirar conclusão.

Quando for estudar, presta atenção em como dois JOINs podem "sair" da mesma tabela em direções diferentes (não é sempre uma cadeia linear A→B→C→D) — isso é comum em modelos com múltiplas dependências, como o seu.
*/

/*
Insight da Pergunta 11 (atualizado em 31/07/2026, após correção de numero_praca — Dia 9)

Resultado: 47 comarcas, variando de 1,36 (São Paulo / Caxias do Sul, empatadas)
a 1,53 (Dourados) praças em média.

Resultado original, antes da correção:
Variação de 1,44 (Aparecida de Goiânia) a 1,70 (Parintins), com Parintins
destacada isoladamente das demais 46 comarcas (que ficavam entre 1,44 e 1,64).

Achado principal da revisão: PARINTINS DEIXOU DE SER OUTLIER
Antes: 1,70 (a mais lenta, destacadamente)
Depois: 1,51 (43º lugar de 47, dentro do intervalo normal)

Isso confirma que Parintins concentrava vários dos 891 casos de "praça única"
mal rotulada corrigidos no Dia 9 — o que inflava artificialmente sua média.
Com a correção, ela caiu para dentro do intervalo normal das demais comarcas.
O "caso especial" identificado originalmente (Dia 8) era, na verdade, um
artefato do erro de numeração de praça, não uma característica real da comarca.

Insight
A eficiência de venda continua homogênea entre comarcas — e ficou ainda mais
homogênea após a correção:
- Amplitude antes: 0,26 (1,44 a 1,70), com 1 outlier isolado
- Amplitude depois: 0,17 (1,36 a 1,53), sem nenhum outlier

Conclusão de negócio (reforçada pela correção): a comarca não é um fator
relevante na velocidade de venda de um lote — a variação entre elas é pequena
e, após a correção dos dados, não há mais nenhuma exceção isolada digna de
investigação. Este é um bom exemplo de como um erro de dado pode gerar uma
falsa pista de investigação (o caso Parintins), corrigida com a devida
auditoria da fonte.
*/