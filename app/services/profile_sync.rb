# Salva o perfil inteiro de uma vez: atualiza itens existentes (pelo id), cria os novos,
# remove os que sumiram e grava a ordem.
class ProfileSync
  def initialize(profile)
    @profile = profile
  end

  def call(params)
    params = params.to_h.deep_symbolize_keys
    Profile.transaction do
      @profile.update!(params.slice(*Profile::FIELDS))
      Profile::SECTIONS.each do |section, attributes|
        next unless params.key?(section)

        sync_section(section, attributes, Array(params[section]))
      end
    end
    @profile.reload
  end

  private

  def sync_section(section, attributes, items)
    association = @profile.public_send(section)
    existing = association.index_by(&:id)
    kept = items.each_with_index.map do |item, position|
      record = existing[item[:id].to_i] || association.build
      record.update!(item.slice(*attributes).merge(position: position))
      record.id
    end
    association.where.not(id: kept).destroy_all
  end
end
