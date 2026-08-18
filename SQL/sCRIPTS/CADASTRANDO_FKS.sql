-- CRIANDO AS FKS. RODE UMA A UMA PARA SABER SE ALGUMA DEU ERRO
-- 1. lote → arrematante
ALTER TABLE lote
ADD CONSTRAINT fk_lote_arrematante
FOREIGN KEY (id_arrematante) REFERENCES arrematante(id_arrematante);

-- 2. cartorio → juiz
ALTER TABLE cartorio
ADD CONSTRAINT fk_cartorio_juiz
FOREIGN KEY (id_Juiz) REFERENCES juiz(id_Juiz);

-- 3. cartorio → localizacao
ALTER TABLE cartorio
ADD CONSTRAINT fk_cartorio_localizacao
FOREIGN KEY (ID_local_cartorio) REFERENCES localizacao(ID_local_cartorio);

-- 4. cartorio → diretor_cartorio
ALTER TABLE cartorio
ADD CONSTRAINT fk_cartorio_diretor
FOREIGN KEY (id_diretor) REFERENCES diretor_cartorio(id_diretor);

-- 5. cartorio → comercial
ALTER TABLE cartorio
ADD CONSTRAINT fk_cartorio_comercial
FOREIGN KEY (id_comercial) REFERENCES comercial(idComercial);

-- 6. processo → cartorio
ALTER TABLE processo
ADD CONSTRAINT fk_processo_cartorio
FOREIGN KEY (id_cartorio) REFERENCES cartorio(Id_cartorio);

-- 7. leilao → praca
ALTER TABLE leilao
ADD CONSTRAINT fk_leilao_praca
FOREIGN KEY (Id_praca) REFERENCES praca(Id_praca);

-- 8. leilao → lote
ALTER TABLE leilao
ADD CONSTRAINT fk_leilao_lote
FOREIGN KEY (id_lote) REFERENCES lote(id_lote);

-- 9. leilao → processo
ALTER TABLE leilao
ADD CONSTRAINT fk_leilao_processo
FOREIGN KEY (id_processo) REFERENCES processo(id_processo);

-- 10. leilao → leiloeiro
ALTER TABLE leilao
ADD CONSTRAINT fk_leilao_leiloeiro
FOREIGN KEY (id_leiloeiro) REFERENCES leiloeiro(id_leiloeiro);