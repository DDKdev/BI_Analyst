import random
import pandas as pd

# Listas de autores
pessoas_fisicas = [
    "João da Silva", "Maria Oliveira", "Carlos Souza", "Ana Paula Lima",
    "Pedro Henrique Santos", "Fernanda Costa", "Ricardo Almeida", "Juliana Rocha"
]

empresas = [
    "TechBrasil S.A.", "AgroVale Ltda.", "Oficina Mecânica do Zé",
    "Construtora Nova Era Ltda.", "GlobalTech Corp."
]

orgaos_publicos = [
    "Prefeitura Municipal de Nova Esperança", "Estado de Santa Aurora",
    "Secretaria de Saúde de Santa Clara", "Instituto Nacional de Energia Renovável"
]

# Lista completa
lista_completa = pessoas_fisicas + empresas + orgaos_publicos

# Tipos de ações
acoes = [
    "Execução Fiscal", "Falência e Recuperação Judicial", "Trabalhista",
    "Execução Cível", "Inventário e partilha", "Execução de alimentos",
    "Busca e apreensão", "Extinção de condomínio", "Ações hipotecárias",
    "Execução de título extrajudicial"
]

# Função para escolher autor conforme regra
def escolher_autor(acao):
    if acao in ["Execução Fiscal", "Falência e Recuperação Judicial"]:
        return random.choice(orgaos_publicos)
    else:
        return random.choice(lista_completa)

# Função para escolher réu (sempre da lista completa)
def escolher_reu():
    return random.choice(lista_completa)

# Gerar 10 mil registros
registros = []
for i in range(10000):
    processo_id = f"P-{i+1:05d}"
    acao = random.choice(acoes)
    autor = escolher_autor(acao)
    reu = escolher_reu()
    registros.append({"processo_id": processo_id, "acao": acao, "autor": autor, "reu": reu})

# Converter para DataFrame
df = pd.DataFrame(registros)

# Exibir os 5 primeiros registros
print(df.head())

# Salvar em CSV
df.to_csv("processos_ficticios.csv", index=False, encoding="utf-8-sig")