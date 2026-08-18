SELECT id_lote, resultado, id_arrematante, valor_lance_final, qtd_lances
FROM lote
WHERE id_lote = 30260;

SELECT COUNT(*)
FROM lote
WHERE resultado = 'Positivo' AND id_arrematante IS NULL;

SELECT id_lote, resultado, id_arrematante, item_id_origem, valor_lance_final, qtd_lances
FROM lote
WHERE resultado = 'Positivo' AND id_arrematante IS NULL
LIMIT 20;

SELECT p.numero_praca, COUNT(*)
FROM lote l
JOIN leilao le ON le.id_lote = l.id_lote
JOIN praca p ON p.Id_praca = le.Id_praca
WHERE l.resultado = 'Positivo' AND l.id_arrematante IS NULL
GROUP BY p.numero_praca;

SELECT COUNT(*)
FROM lote l1
JOIN lote l2
    ON l2.processo_origem = l1.processo_origem
    AND l2.lote_origem = l1.lote_origem
    AND l2.sublote_origem = l1.sublote_origem
    AND l2.id_lote != l1.id_lote
WHERE l1.resultado = 'Positivo' 
  AND l1.id_arrematante IS NULL
  AND l2.id_arrematante IS NOT NULL;
  
  SELECT l1.id_lote, l1.resultado, l1.id_arrematante, l1.processo_origem, 
       l1.lote_origem, l1.sublote_origem, p.numero_praca
FROM lote l1
JOIN leilao le ON le.id_lote = l1.id_lote
JOIN praca p ON p.Id_praca = le.Id_praca
WHERE l1.resultado = 'Positivo' 
  AND l1.id_arrematante IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM lote l2
      WHERE l2.processo_origem = l1.processo_origem
        AND l2.lote_origem = l1.lote_origem
        AND l2.sublote_origem = l1.sublote_origem
        AND l2.id_lote != l1.id_lote
        AND l2.id_arrematante IS NOT NULL
  );

SELECT Item_ID, Processo, Lote, SubLote, Praca, Arrematante, Resultado
FROM leilao_bruto
WHERE Processo = '032899510' AND Lote = 1 AND SubLote = 1;

SELECT COUNT(*) FROM leilao_bruto WHERE Arrematante = 'Nomes arrematantes';

UPDATE lote l
JOIN leilao_bruto b ON b.Item_ID = l.item_id_origem
SET l.resultado = 'Negativo'
WHERE b.Arrematante = 'Nomes arrematantes';

-- Não deve sobrar nenhum "Positivo" sem arrematante
SELECT COUNT(*)
FROM lote
WHERE resultado = 'Positivo' AND id_arrematante IS NULL;

SELECT COUNT(*)
FROM lote l1
JOIN leilao_bruto b1 ON b1.Item_ID = l1.item_id_origem
JOIN lote l2
    ON l2.processo_origem = l1.processo_origem
    AND l2.lote_origem = l1.lote_origem
    AND l2.sublote_origem = l1.sublote_origem
    AND l2.id_lote != l1.id_lote
WHERE l1.resultado = 'Positivo' 
  AND l1.id_arrematante IS NULL
  AND l2.id_arrematante IS NOT NULL
  AND b1.Arrematante = 'Nomes arrematantes';
  
  SELECT b.Arrematante, COUNT(*)
FROM lote l1
JOIN leilao_bruto b ON b.Item_ID = l1.item_id_origem
JOIN lote l2
    ON l2.processo_origem = l1.processo_origem
    AND l2.lote_origem = l1.lote_origem
    AND l2.sublote_origem = l1.sublote_origem
    AND l2.id_lote != l1.id_lote
WHERE l1.resultado = 'Positivo' 
  AND l1.id_arrematante IS NULL
  AND l2.id_arrematante IS NOT NULL
GROUP BY b.Arrematante
ORDER BY COUNT(*) DESC
LIMIT 10;

-- 1. Corrigir a inconsistência nova: "Nomes arrematantes" (cabeçalho vazado)
UPDATE lote l
JOIN leilao_bruto b ON b.Item_ID = l.item_id_origem
SET l.resultado = 'Negativo'
WHERE b.Arrematante = 'Nomes arrematantes';

-- 2. Sincronizar 'resultado' com id_arrematante para TODA a tabela
--    (resolve os 467 remanescentes do Dia 11, e qualquer outro caso futuro)
UPDATE lote
SET resultado = CASE 
    WHEN id_arrematante IS NOT NULL THEN 'Positivo'
    ELSE 'Negativo'
END;

SET SQL_SAFE_UPDATES = 0;

UPDATE lote
SET resultado = CASE 
    WHEN id_arrematante IS NOT NULL THEN 'Positivo'
    ELSE 'Negativo'
END;

SET SQL_SAFE_UPDATES = 1;

-- 1. A primeira query rodou? Quantas linhas ela alterou?
--    (se você já rodou antes dessa segunda, me diga o resultado dela)

-- 2. Situação atual - ainda existe inconsistência?
SELECT COUNT(*) FROM lote WHERE resultado = 'Positivo' AND id_arrematante IS NULL;
SELECT COUNT(*) FROM lote WHERE resultado = 'Negativo' AND id_arrematante IS NOT NULL;