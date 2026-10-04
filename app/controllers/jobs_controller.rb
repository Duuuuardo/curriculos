class JobsController < ApplicationController
  PANELS = %w[analise ajustar vaga carta].freeze

  before_action :set_job, only: %i[show update destroy duplicate ignore_keyword reset_overrides]

  def index
    load_index
  end

  def show
    @panel = params[:panel].presence_in(PANELS) || "analise"
    tailor = ResumeTailor.new(@job)
    @analysis = tailor.analysis.as_json.deep_symbolize_keys
    @resume = tailor.resume
    @highlight_terms = @analysis[:keywords].select { |k| k[:matched] }.flat_map { |k| [ k[:label], *k[:variants] ] }
  end

  def create
    @job = Job.new(job_params)
    if @job.save
      redirect_to job_path(@job), notice: "Vaga criada!", status: :see_other
    else
      load_index
      render :index, status: :unprocessable_content
    end
  end

  def update
    permitted = job_params
    if (incoming = permitted.delete(:overrides))
      booleans = incoming.to_h.transform_values { |v| ActiveModel::Type::Boolean.new.cast(v) }
      @job.overrides = @job.overrides.merge(booleans)
    end
    @job.update!(permitted)
    redirect_back_to_panel
  end

  def destroy
    @job.destroy!
    redirect_to jobs_path, notice: "Vaga excluída.", status: :see_other
  end

  def duplicate
    copy = @job.dup
    copy.title = "#{@job.title} (cópia)"
    copy.status = "salva"
    if params[:language].present? && params[:language] != @job.language
      copy.language = params[:language]
      copy.title = "#{@job.title} (#{params[:language].upcase})"
      copy.overrides = {}
    end
    copy.save!
    redirect_to job_path(copy), notice: "Vaga duplicada: #{copy.title}", status: :see_other
  end

  def ignore_keyword
    @job.update!(ignored_keywords: @job.ignored_keywords + [ params[:keyword].to_s ])
    redirect_back_to_panel
  end

  def reset_overrides
    @job.update!(overrides: {})
    redirect_back_to_panel
  end

  private

  def set_job
    @job = Job.find(params[:id])
  end

  def load_index
    @jobs = Job.recent
    @show_form = params[:new].present? || @job&.errors&.any?
    @filter = params[:status].presence_in(Job::STATUSES)
    @visible = @filter ? @jobs.select { |job| job.status == @filter } : @jobs
    profiles = Hash.new { |cache, language| cache[language] = Profile.for(language) }
    @scores = @jobs.to_h { |job| [ job.id, JobAnalysis.new(job, profiles[job.language]).score ] }
  end

  def redirect_back_to_panel
    redirect_to job_path(@job, panel: params[:panel].presence, anchor: "panel"), status: :see_other
  end

  def job_params
    params.require(:job).permit(
      :title, :company, :url, :description, :language, :status, :notes, :custom_headline, :custom_summary, :cover_letter,
      :ai_instructions,
      extra_keywords: [], ignored_keywords: [], overrides: {}
    )
  end
end
