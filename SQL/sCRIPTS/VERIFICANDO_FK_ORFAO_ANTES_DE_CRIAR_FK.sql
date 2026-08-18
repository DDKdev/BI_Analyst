-- checando se não há nenhuma chave orfão, apontando para nenhuma tabela
-- Antes de criar as queries das FKs
-- todas devem retornar 0

-- EXPLICAÇÃO
-- A ideia central: usar o LEFT JOIN para "caçar" quem não tem correspondência
-- Lembra que o LEFT JOIN mantém todas as linhas da tabela da esquerda (lote), 
	-- mesmo quando não encontra correspondência na tabela da direita (arrematante)? 
    -- Quando isso acontece — quando não há correspondência — todas as colunas vindas da tabela da direita 
    --	aparecem como NULL no resultado.
-- É exatamente essa característica que a query explora, de um jeito meio "espertinho": 
	-- ela usa o LEFT JOIN não pra trazer dados, mas como um teste de existência.

-- Passo a passo:
/*FROM lote l LEFT JOIN arrematante a ON l.id_arrematante = a.id_arrematante — 
	-- para cada linha de lote, tenta achar uma linha em arrematante com o mesmo id_arrematante.
WHERE l.id_arrematante IS NOT NULL — 
	-- filtra só os lotes que têm um id_arrematante preenchido (ignora os lotes sem comprador, que legitimamente têm NULL ali — isso não é o que queremos investigar).
AND a.id_arrematante IS NULL — 
	--aqui está o pulo do gato. Se o lote tinha um id_arrematante preenchido, 
    -- mas depois do JOIN a coluna vinda de arrematante voltou NULL, isso só pode significar uma coisa: 
    -- o JOIN não achou correspondência — ou seja, aquele ID gravado em lote não existe na tabela arrematante. Um "FK fantasma", apontando pro nada.
SELECT COUNT(*) — 
	-- conta quantas linhas caem nessa situação.*/


SELECT COUNT(*) FROM lote l
LEFT JOIN arrematante a ON l.id_arrematante = a.id_arrematante
WHERE l.id_arrematante IS NOT NULL AND a.id_arrematante IS NULL;

SELECT COUNT(*) FROM cartorio c
LEFT JOIN juiz j ON c.id_Juiz = j.id_Juiz
WHERE c.id_Juiz IS NOT NULL AND j.id_Juiz IS NULL;

SELECT COUNT(*) FROM cartorio c
LEFT JOIN localizacao loc ON c.ID_local_cartorio = loc.ID_local_cartorio
WHERE c.ID_local_cartorio IS NOT NULL AND loc.ID_local_cartorio IS NULL;

SELECT COUNT(*) FROM cartorio c
LEFT JOIN diretor_cartorio d ON c.id_diretor = d.id_diretor
WHERE c.id_diretor IS NOT NULL AND d.id_diretor IS NULL;

SELECT COUNT(*) FROM cartorio c
LEFT JOIN comercial co ON c.id_comercial = co.idComercial
WHERE c.id_comercial IS NOT NULL AND co.idComercial IS NULL;

SELECT COUNT(*) FROM processo p
LEFT JOIN cartorio c ON p.id_cartorio = c.Id_cartorio
WHERE p.id_cartorio IS NOT NULL AND c.Id_cartorio IS NULL;

SELECT COUNT(*) FROM leilao le
LEFT JOIN praca p ON le.Id_praca = p.Id_praca
WHERE le.Id_praca IS NOT NULL AND p.Id_praca IS NULL;

SELECT COUNT(*) FROM leilao le
LEFT JOIN lote l ON le.id_lote = l.id_lote
WHERE le.id_lote IS NOT NULL AND l.id_lote IS NULL;

SELECT COUNT(*) FROM leilao le
LEFT JOIN processo p ON le.id_processo = p.id_processo
WHERE le.id_processo IS NOT NULL AND p.id_processo IS NULL;

SELECT COUNT(*) FROM leilao le
LEFT JOIN leiloeiro l ON le.id_leiloeiro = l.id_leiloeiro
WHERE le.id_leiloeiro IS NOT NULL AND l.id_leiloeiro IS NULL;