import itertools
import random
import pandas as pd

# Listas de nomes fictícios
primeiros_nomes = [
    "João", "Maria", "José", "Ana", "Pedro", "Lucas", "Mariana", "Carlos", "Fernanda", "Paulo",
    "Camila", "Rafael", "Juliana", "André", "Patrícia", "Bruno", "Daniela", "Felipe", "Aline", "Gustavo",
    "Letícia", "Rodrigo", "Bianca", "Eduardo", "Vanessa", "Diego", "Larissa", "Gabriel", "Renata", "Thiago",
    "Simone", "Leonardo", "Cláudia", "Marcelo", "Tatiane", "Alexandre", "Fabiana", "Roberto", "Adriana", "Mateus",
    "Priscila", "Igor", "Mônica", "Vinícius", "Débora", "Fábio", "Sônia", "Henrique", "Cecília", "Murilo",
    "Rosa", "Samuel", "Carla", "Vitor", "Elisângela", "Daniel", "Rafaela", "Jorge", "Michele", "Antônio",
    "Bruna", "Caio", "Érica", "Sérgio", "Talita", "Wallace", "Cristiane", "Everton", "Luciana", "Hugo",
    "Jaqueline", "Osmar", "Eliane", "Cássio", "Márcia", "Davi", "Joana", "Alan", "Kelly", "Wagner",
    "Regina", "Cristiano", "Helena", "Mauro", "Isabela", "Nilson", "Teresa", "Douglas", "Flávia", "Renato",
    "Paula", "Silvio", "Natália", "Nelson", "Roberta", "Álvaro", "Gabriela", "Luciano", "Sofia", "Guilherme"
]

sobrenomes = [
    "Silva", "Santos", "Oliveira", "Souza", "Rodrigues", "Ferreira", "Alves", "Pereira", "Lima", "Gomes",
    "Costa", "Martins", "Araújo", "Melo", "Castro", "Carvalho", "Rocha", "Dias", "Nunes", "Pinto",
    "Teixeira", "Correia", "Moreira", "Barros", "Cardoso", "Monteiro", "Batista", "Campos", "Moura", "Ribeiro",
    "Cunha", "Duarte", "Tavares", "Freitas", "Guimarães", "Pires", "Farias", "Macedo", "Sales", "Braga",
    "Coelho", "Neves", "Magalhães", "Bezerra", "Brito", "Moraes", "Azevedo", "Rezende", "Bastos", "Fonseca",
    "Simões", "Santana", "Porto", "Prado", "Antunes", "Valente", "Peixoto", "Siqueira", "Barreto", "Amorim",
    "Queiroz", "Xavier", "Assis", "Lemos", "Figueiredo", "Cintra", "Holanda", "Loureiro", "Mascarenhas", "Aragão",
    "Benevides", "Coutinho", "Damasceno", "Dorneles", "Estrela", "França", "Gouveia", "Leitão", "Maia", "Marinho",
    "Medeiros", "Mendonça", "Mesquita", "Paiva", "Passos", "Pedrosa", "Quevedo", "Rangel", "Sampaio", "Saraiva",
    "Seabra", "Serafim", "Teles", "Torres", "Vasconcelos", "Viana", "Vieira", "Zago", "Rezende", "Barros"
]

# Gerar todas as combinações possíveis
combinacoes = list(itertools.product(primeiros_nomes, sobrenomes))

# Embaralhar para evitar padrão repetitivo
random.shuffle(combinacoes)

# Selecionar até 10 mil combinações
combinacoes = combinacoes[:10000]

# Criar DataFrame
df = pd.DataFrame(combinacoes, columns=["primeiro_nome", "sobrenome"])

# Criar coluna com nome completo
df["nome_completo"] = df["primeiro_nome"] + " " + df["sobrenome"]

# Exibir os 5 primeiros registros
print(df.head())

# Salvar em CSV
df.to_csv("nomes_ficticios.csv", index=False, encoding="utf-8-sig")