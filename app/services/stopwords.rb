module Stopwords
  PORTUGUESE = %w[
    a ao aos as ate com como da das de dela dele do dos e ela ele em entre era essa esse esta este eu foi ha isso isto ja
    la lhe mais mas me mesmo meu minha muito na nao nas nem no nos nossa nosso num numa o os ou para pela pelas pelo pelos
    por qual quando que quem se sem ser seu sua suas seus so sob sobre tambem te tem ter seja sao sera serao voce voces
    um uma umas uns vai vao sua todo toda todos todas cada outro outra outros outras bem onde aqui assim pois estar estamos
    esta estao fazer faz parte forma atraves alem bem como tipo
  ].freeze

  ENGLISH = %w[
    a about above after all also an and any are as at be been being but by can could do does for from had has have how
    if in into is it its may more most must no not of on or our ours out over own should so some such than that the their
    them then there these they this those through to under up very was we were what when where which while who will with
    would you your yours us able across within etc per
  ].freeze

  JOB_POSTING = %w[
    vaga vagas empresa empresas oportunidade oportunidades candidato candidata candidatos pessoa pessoas profissional
    profissionais buscamos procuramos requisitos requisito desejavel desejaveis diferencial diferenciais beneficios beneficio
    responsabilidades responsabilidade atividades atividade experiencia experiencias conhecimento conhecimentos area areas
    time times equipe trabalho trabalhar atuar atuacao junto nivel anos ano sera somos nossa nossos nossas clientes cliente
    desenvolver desenvolvimento modelo contratacao clt pj remoto hibrido presencial salario vale refeicao alimentacao
    saude odontologico plano local horario dia dias mes meses semana bom boa boas grande novo nova novos novas melhor
    melhores principais principal dominio solida solido forte fortes capacidade habilidade habilidades vivencia
    sobre voce valorizamos todas todos diversidade inclusao etapa etapas processo seletivo
    job jobs role roles company team teams candidate candidates looking requirements requirement responsibilities
    responsibility preferred nice plus benefits benefit experience experiences knowledge years year work working strong
    skills skill ability abilities position opportunity opportunities apply including include includes new using use
    based help join well good great best other others ensure environment
  ].freeze

  ALL = (PORTUGUESE + ENGLISH + JOB_POSTING).to_set.freeze

  def self.include?(word)
    ALL.include?(word)
  end
end
