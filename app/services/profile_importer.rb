# Mescla dados extraídos de um PDF no perfil SEM apagar o que já existe:
# campos vazios do perfil são preenchidos e itens novos são anexados no fim
# de cada seção (com deduplicação simples). Retorna contadores para o flash.
class ProfileImporter
  def initialize(profile)
    @profile = profile
  end

  # data: hash no formato devolvido por ResumeImport
  def merge(data)
    counts = {}
    @profile.transaction do
      counts[:fields] = fill_scalars(data)
      counts[:experiences] = append(:experiences, data[:experiences]) do |o|
        identity(read(o, :company), read(o, :role), read(o, :start_date))
      end
      counts[:projects] = append(:projects, data[:projects]) do |o|
        identity(read(o, :name))
      end
      counts[:educations] = append(:educations, data[:educations]) do |o|
        identity(read(o, :institution), read(o, :field))
      end
      counts[:skills] = append(:skills, data[:skills]) do |o|
        identity(read(o, :name))
      end
      counts[:languages] = append(:languages, data[:languages]) do |o|
        identity(read(o, :name))
      end
      counts[:certifications] = append(:certifications, data[:certifications]) do |o|
        identity(read(o, :name), read(o, :issuer))
      end
    end
    counts
  end

  private

  def fill_scalars(data)
    filled = Profile::FIELDS.count do |field|
      next false if @profile.public_send(field).present? || data[field].blank?

      @profile.public_send(:"#{field}=", data[field])
      true
    end
    @profile.save!
    filled
  end

  # O bloco calcula a chave de identidade — serve tanto para registros já
  # salvos quanto para os hashes do import, para não duplicar itens.
  def append(section, items, &key)
    items = Array(items).reject { |item| item.values.all?(&:blank?) }
    return 0 if items.empty?

    association = @profile.public_send(section)
    existing = association.map(&key).to_set
    position = association.count

    items.count do |item|
      item_key = key.call(item)
      next false if existing.include?(item_key)

      association.create!(item.slice(*Profile::SECTIONS[section]).compact.merge(position: position))
      existing << item_key
      position += 1
      true
    end
  end

  def read(obj, field)
    obj.is_a?(Hash) ? obj[field] : obj.public_send(field)
  end

  def identity(*parts)
    parts.map { |part| TextNormalizer.fold(part) }.join("|")
  end
end
