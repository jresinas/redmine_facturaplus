class SageArticlesController < ApplicationController
  layout 'admin'
  before_filter :require_admin
  before_action :get_sage_article, only: [:edit, :update, :destroy]

  # GET /sage_articles
  # GET /sage_articles.json
  def index
    @sage_articles = SageArticle.all
  end

  # GET /sage_articles/1
  # GET /sage_articles/1.json
  def show
  end

  # GET /sage_articles/new
  def new
    @sage_article = SageArticle.new
  end

  # GET /sage_articles/1/edit
  def edit
  end

  # POST /sage_articles
  # POST /sage_articles.json
  def create
    @sage_article = SageArticle.new(sage_article_params)

    if @sage_article.save
      flash[:notice] = l(:"facturaplus.sage_articles.text_create_notice")
      if params[:continue]
        redirect_to action: 'new'
      else
        redirect_to sage_articles_path
      end
    else
      flash[:error] = @sage_article.errors.full_messages.join('<br>').html_safe
      redirect_to action: 'new'
    end
  end

  # PATCH/PUT /sage_articles/1
  # PATCH/PUT /sage_articles/1.json
  def update
    if @sage_article.update(sage_article_params)
      flash[:notice] = l(:"facturaplus.sage_articles.text_update_notice")
      redirect_to sage_articles_path
    else
      flash[:error] = @sage_article.errors.full_messages.join('<br>').html_safe
      redirect_to action: 'edit', :id => params[:sage_article][:id]
    end
  end

  # DELETE /sage_articles/1
  # DELETE /sage_articles/1.json
  def destroy
    @sage_article.destroy
    flash[:notice] = l(:"facturaplus.sage_articles.text_delete_notice_success")
    redirect_to sage_articles_path
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def get_sage_article
      @sage_article = SageArticle.find(params[:id]) if params[:id].present?
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def sage_article_params
      params.require(:sage_article).permit(:service_id, :service_name, :article_id)
    end
end
