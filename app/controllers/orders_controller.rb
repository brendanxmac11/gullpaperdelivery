require 'pdf-reader'
require 'fileutils'
class OrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: [:show, :edit, :update, :destroy]
  before_action :require_same_user, only: [:edit, :update, :destroy]

  # GET /orders
  # GET /orders.json
  def index
    @orders = Order.paginate(page: params[:page], per_page:11)
  end

  # GET /orders/1
  # GET /orders/1.json
  def show
  end

  # GET /orders/new
  def new
    @order = Order.new
  end

  # GET /orders/1/edit
  def edit
  end

  # POST /orders
  # POST /orders.json
  def create
    @order = Order.new(order_params)
    @order.user = current_user
    @order.status = "Waiting for Venmo Payment"
    if @order.delivery_time == "Express"
      @order.price = 4.00
    elsif @order.delivery_time == "Overnight (before 7AM)"
      @order.price = 3.00
    elsif @order.delivery_time == "7:00-8:00PM"
      @order.price = 2.00
    elsif  @order.delivery_time == "10:00-11:00PM"
      @order.price = 2.50
    end

    # attachment = @order.attachment
    # PDF::Reader.open("#{Rails.root}/public"+attachment.to_s) do |reader|
    #   # puts reader.page_count
    #   pages = reader.page_count.to_int
    #   @order.page_count = pages
    #   page_price = pages * (0.05)
    #   @order.price += page_price
    #   # puts @order.price
    # end

    respond_to do |format|
      if @order.save
        OrderMailer.order_email(@order, @order.user).deliver_now
        OrderMailer.order_admin_email(@order, @order.user).deliver_now
        format.html { redirect_to @order, notice: 'Order was successfully created.' }
        format.json { render :show, status: :created, location: @order }
      else
        format.html { render :new }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  def out_for_delivery
    @order = Order.find(params[:id])
    @order.status = "Out for Delivery"
    userID = @order.user_id
    user = User.find(userID)
    if @order.save
      OrderMailer.payment_recieved_admin_email(@order, @order.user).deliver_now
      OrderMailer.payment_recieved_user_email(@order, @order.user).deliver_now
      redirect_to orders_url, notice: 'Order is out for delivery, Payment was recieved'
    end
  end

  def delivered
    @order = Order.find(params[:id])
    @order.status = "Delivered"
    userID = @order.user_id
    user = User.find(userID)
    if @order.save
      OrderMailer.order_delivered_admin_email(@order, @order.user).deliver_now
      OrderMailer.order_delivered_user_email(@order, @order.user).deliver_now
      redirect_to orders_url, notice: 'Order was successfully delivered.'
    end
    puts @order.attachment.to_s
    File.delete("#{Rails.root}/public"+@order.attachment.to_s)
    puts @order.attachment.to_s
    FileUtils.rm_rf("#{Rails.root}/public/uploads/order/attachment/"+@order.id.to_s)
    puts @order.attachment.to_s

  end

  # PATCH/PUT /orders/1
  # PATCH/PUT /orders/1.json
  def update
    respond_to do |format|
      if @order.update(order_params)
        format.html { redirect_to @order, notice: 'Order was successfully updated.' }
        format.json { render :show, status: :ok, location: @order }
      else
        format.html { render :edit }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /orders/1
  # DELETE /orders/1.json
  def destroy
    @order.destroy
    respond_to do |format|
      format.html { redirect_to orders_url, notice: 'Order was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_order
      @order = Order.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def order_params
      params.require(:order).permit(:title, :location, :delivery_time, :details, :attachment, :status, :user_id)
    end

    def require_same_user
      if current_user != @order.user and !current_user.admin?
        flash[:danger] = "You can only edit or delete you own orders"
        redirect_to orders_path
      end
    end
end
