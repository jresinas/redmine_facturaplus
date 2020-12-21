class SageAssociationsController < ApplicationController
  layout 'admin'
  before_filter :require_admin
  before_filter :get_type, :only => [:new, :edit]
  before_filter :get_source, :only => [:new, :edit]
  before_action :get_sage_association, only: [:edit, :update, :destroy]

  # GET /sage_associations
  # GET /sage_associations.json
  def index
    @sage_associations = SageAssociation.all
  end

  # GET /sage_associations/1
  # GET /sage_associations/1.json
  def show
  end

  # GET /sage_associations/new
  def new
    @sage_association = SageAssociation.new
  end

  # GET /sage_associations/1/edit
  def edit
  end

  # POST /sage_associations
  # POST /sage_associations.json
  def create
    @sage_association = SageAssociation.new(sage_association_params)

    if @sage_association.save
      flash[:notice] = l(:"facturaplus.sage_associations.text_create_notice")
      if params[:continue]
        redirect_to action: 'new', :type => params[:sage_association][:data_type]
      else
        redirect_to sage_associations_path
      end
    else
      flash[:error] = @sage_association.errors.full_messages.join('<br>').html_safe
      redirect_to action: 'new', :type => params[:sage_association][:data_type]
    end
  end

  # PATCH/PUT /sage_associations/1
  # PATCH/PUT /sage_associations/1.json
  def update
    if @sage_association.update(sage_association_params)
      flash[:notice] = l(:"facturaplus.sage_associations.text_update_notice")
      redirect_to sage_associations_path
    else
      flash[:error] = @sage_association.errors.full_messages.join('<br>').html_safe
      redirect_to action: 'edit', :id => params[:sage_association][:id], :type => params[:sage_association][:data_type]
    end
  end

  # DELETE /sage_associations/1
  # DELETE /sage_associations/1.json
  def destroy
    @sage_association.destroy
    flash[:notice] = l(:"facturaplus.sage_associations.text_delete_notice_success")
    redirect_to sage_associations_path
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def get_sage_association
      @sage_association = SageAssociation.find(params[:id]) if params[:id].present?
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def sage_association_params
      params.require(:sage_association).permit(:source_id, :source_name, :target_code, :data_type)
    end

    # Obtiene el tipo de elemento que se está modificando (articles o billers)
    def get_type
      @type = params[:type].present? ? params[:type] : nil
    end

    # Obtiene los datos del origen necesarios (para servicios y emisores)
    def get_source
      case @type
      when 'Article'
          get_source_services
      when 'Biller'
          get_source_billers
      when 'Currency'
          get_source_currencies
      when 'Section'
          get_source_business_units
      when 'SageProject'
          get_source_business_lines
      end
    end

    def get_source_services
      @source = ProjectCustomField.find(Setting.plugin_redmine_facturaplus['service_field']).enumerations
    end

    def get_source_billers
      @source = IssueCustomField.find(Setting.plugin_redmine_facturaplus['biller_field']).enumerations
    end

    def get_source_currencies
      @source = IssueCustomField.find(Setting.plugin_redmine_facturaplus['currency_field']).enumerations
    end

    def get_source_business_units
      @source = ProjectCustomField.find(Setting.plugin_redmine_facturaplus['business_unit_field']).enumerations
    end

    def get_source_business_lines
      @source = ProjectCustomField.find(Setting.plugin_redmine_facturaplus['business_line_field']).enumerations
    end
end
