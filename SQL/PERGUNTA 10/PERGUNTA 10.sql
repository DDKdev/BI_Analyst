/*
	Pergunta 10 (Bloco 1 — Eficiência judicial)

Qual a taxa de sucesso de venda na 1ª praça vs. 2ª praça vs. 3ª praça (e seguintes)?

A ideia: será que a maioria das vendas acontece já na 1ª tentativa, ou o mercado realmente depende do desconto/repetição em praças seguintes (como é comum se falar sobre leilão judicial)?
*/

SELECT
    p.numero_praca,
    COUNT(*) AS total_ofertado,
    SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) AS total_vendido,
    ROUND(
        SUM(CASE WHEN l.id_arrematante IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) * 100,
        2
    ) AS taxa_venda_percentual
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN praca p ON p.Id_praca = le.Id_praca
GROUP BY p.numero_praca
ORDER BY p.numero_praca;

/*
	O que muda em relação às perguntas anteriores (5 e 7):
Dois JOINs em vez de um — porque numero_praca não está diretamente ligado a lote; o caminho é lote → leilao (que conecta os dois) → praca (onde está o número da praça).
GROUP BY p.numero_praca — em vez de agrupar por categoria ou leiloeiro, agrupamos pelo número da tentativa (1ª, 2ª, 3ª praça...).
ORDER BY p.numero_praca (não DESC) — aqui faz mais sentido ordenar crescente (1, 2, 3...), porque queremos ver a progressão natural das tentativas, não um ranking do "melhor pra pior".
A mesma estrutura de SUM(CASE WHEN...) — igual usamos nas Perguntas 5 e 7, pra contar "vendidos" e "total" na mesma passada.

Quando for estudar, presta atenção especial em como o JOIN duplo funciona (percorrendo de uma tabela "distante" até a que você precisa, passando por uma tabela intermediária) — isso é um padrão que você vai usar bastante daqui pra frente. Qualquer dúvida na lógica, é só chamar antes de rodar.
*/

/*
Insight da Pergunta 10

Resultado (atualizado em 31/07/2026, após correção da numeração de praça — Dia 9):

Praça       Total ofertado    Total vendido    Taxa de venda
1ª             20.027              4.923           24,58%
2ª             15.121              3.760           24,87%
3ª (única)        150                 97           64,67%

Validação: soma bate com os totais gerais (20.027 + 15.121 + 150 = 35.298)

Resultado original, antes da correção:
1ª praça 24,79% (18.099 ofertados)
2ª praça 24,87% (15.121 ofertados)
3ª praça 25,65% (2.078 ofertados)

Insight
Taxa de sucesso praticamente estável entre 1ª e 2ª praça — não se confirma 
a crença comum de que a 2ª praça (com desconto) venderia proporcionalmente 
mais que a 1ª.

Achado relevante após a correção: isolada a "praça única" de fato (removidos 
os 891 casos que eram, na verdade, 1ª praça mal rotulada como praça única), 
sua taxa de conversão é dramaticamente superior às demais — 64,67%, contra 
~24-25% nas praças 1 e 2.

Hipótese (não comprovada pelos dados): a modalidade de praça única pode ser 
determinada pelo juiz justamente em casos com maior probabilidade de venda 
(ex.: interessado pré-identificado, bem de alta liquidez), o que explicaria 
essa taxa de sucesso muito maior em comparação ao leilão bifásico padrão.

Nota: os dados deste dataset são fictícios, gerados via fórmulas em Excel 
para fins de estudo. A distribuição real de vendas entre praças em um leilão 
judicial de verdade tende a concentrar a grande maioria das vendas na 2ª 
praça (o valor de abertura cai para ~40-50% do valor da 1ª praça, tornando-a 
mais atrativa) — padrão que este dataset não reproduz nesta versão. Ver 
pendência registrada no diário (Dia 10) para ajuste em versão futura do projeto.
*/