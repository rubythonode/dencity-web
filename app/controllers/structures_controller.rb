# structure controller
class StructuresController < ApplicationController
  load_and_authorize_resource param_method: :structure_params
  before_action :set_structure, only: [:show, :edit, :update, :destroy, :download_related_file]

  # GET /structures
  # GET /structures.json
  def index
    # @search = Sunspot.search(Structure) do
    #   fulltext params[:q] do
    #     #boost_fields :name => 2.0, :description => 1.5
    #
    #     #highlight :name, :fragment_size => 255
    #     #highlight :description, :fragment_size => 60, :max_snippets => 4, :merge_contiguous_fragments => true
    #   end
    # end

    @search = Sunspot.search(Structure) do
      params[:per_page] ||= 100
      params[:order] ||= 'score'

      fulltext params[:search]

      facet_filters = {}
      if params[:f]
        params[:f].each do |facet_field, values|
          case values
            when Array
              facet_filters[facet_field] = with(facet_field, Range.new(*values.first.split('..').map(&:to_i)))
            else
              if facet_field != 'type' || values != ['any']
                facet_filters[facet_field] = with(facet_field).any_of(values)
              end
          end
        end
      end

      if params[:r]
        params[:r].each do |facet_field, input_value|
          values = input_value.split(';').map(&:to_i)
          range = values.first..values.last
          with(facet_field).between(range)
        end
      end

      # Make sure to return the stats of some objects for the facets
      # facet :building_type
      stats :building_area
      facet :building_area, range: 0..100_000, range_interval: 1000 # , exclude: facet_filters['building_area']
      stats :total_site_eui
      facet :total_site_eui, range: 0..1500, range_interval: 100 # , exclude: facet_filters['total_site_eui']

      paginate page: params[:page], per_page: params[:per_page]
    end
  end

  # GET /structures/1
  # GET /structures/1.json
  def show
  end

  # GET /structures/new
  def new
    @structure = Structure.new
  end

  # GET /structures/1/edit
  def edit
  end

  # POST /structures
  # POST /structures.json
  def create
    @structure = current_user.structures.new(structure_params)

    respond_to do |format|
      if @structure.save
        format.html { redirect_to @structure, notice: 'Structure was successfully created.' }
        format.json { render action: 'show', status: :created, location: @structure }
      else
        format.html { render action: 'new' }
        format.json { render json: @structure.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /structures/1
  # PATCH/PUT /structures/1.json
  def update
    respond_to do |format|
      if @structure.update(structure_params)
        format.html { redirect_to @structure, notice: 'Structure was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @structure.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /structures/1
  # DELETE /structures/1.json
  def destroy
    @structure.destroy
    respond_to do |format|
      format.html { redirect_to structures_url }
      format.json { head :no_content }
    end
  end

  # download a related file
  def download_file
    file = @structure.related_files.find(params[:related_file_id])

    fail 'file not found in database' unless file

    file_data = get_file_data(file)
    if file_data
      send_data file_data, filename: File.basename(file.uri), type: 'application/octet-stream; header=present', disposition: 'attachment'
    else
      fail 'file not found in database'
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_structure
    @structure = Structure.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def structure_params
    params.require(:structure).permit(:name, :other_field, analysis_attributes: [:id], user_attributes: [:id])
  end

  # download a file
  def get_file_data(file)
    begin
      file_data = nil
      fail 'File not stored on the server' unless File.exist?("#{Rails.root}#{file.uri}")
      file_data = File.read("#{Rails.root}#{file.uri}")

      fail "Could not find file to download #{file.uri}" if file_data.nil?
    rescue => e
      flash[:notice] = "Could not find file to download #{file.uri}. #{e.message}"
      logger.error "Could not find file to download #{file.uri}. #{e.message}"
      redirect_to(:back)
    end

    file_data
  end
end
