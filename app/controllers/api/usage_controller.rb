module Api
  class UsageController < ApplicationController
    # GET /api/usage/log
    def log
      records = UsageRecord.where(landlord_id: @landlord_id).order(called_at: :desc)
      records = records.where(call_type: params[:call_type]) if params[:call_type].present?
      records = records.where(called_at: date_range) if params[:start_date].present?

      page = (params[:page] || 1).to_i
      per_page = 50
      total = records.count
      records = records.offset((page - 1) * per_page).limit(per_page)

      render json: {
        records: records.map { |r| format_record(r) },
        total: total,
        page: page,
        pages: (total / per_page.to_f).ceil
      }
    end

    # GET /api/usage/summary
    def summary
      all_records = UsageRecord.where(landlord_id: @landlord_id)
      this_month = all_records.where(called_at: Time.current.beginning_of_month..)

      by_type = this_month.group(:call_type).sum(:total_charged_cents)
      last_12 = (0..11).map do |i|
        start = i.months.ago.beginning_of_month
        finish = i.months.ago.end_of_month
        total = all_records.where(called_at: start..finish).sum(:total_charged_cents)
        { month: start.strftime("%b %Y"), total_cents: total }
      end.reverse

      render json: {
        total_this_month_cents: this_month.sum(:total_charged_cents),
        total_all_time_cents: all_records.sum(:total_charged_cents),
        calls_this_month: this_month.count,
        by_call_type: by_type,
        last_12_months: last_12
      }
    end

    # POST /api/billing/usage
    # Called by the WASM client to log usage after a Plaid call
    def record
      rec = UsageRecord.create!(
        landlord_id: @landlord_id,
        call_type: params.require(:call_type),
        plaid_request_id: params[:plaid_request_id],
        raw_cost_cents: params[:raw_cost_cents].to_i,
        markup_cents: params[:markup_cents].to_i,
        total_charged_cents: params[:total_charged_cents].to_i,
        charged_to: params[:charged_to] || "landlord",
        status: params[:status] || "success",
        called_at: params[:called_at] || Time.current,
        property_id: params[:property_id],
        unit_id: params[:unit_id],
        tenant_id: params[:tenant_id],
        notes: params[:notes]
      )
      render json: { id: rec.id }, status: :created
    end

    private

    def date_range
      start_date = Date.parse(params[:start_date])
      end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.today
      start_date.beginning_of_day..end_date.end_of_day
    end

    def format_record(r)
      {
        id: r.id,
        called_at: r.called_at,
        call_type: r.call_type,
        plaid_request_id: r.plaid_request_id,
        property_id: r.property_id,
        unit_id: r.unit_id,
        tenant_id: r.tenant_id,
        raw_cost_cents: r.raw_cost_cents,
        markup_cents: r.markup_cents,
        total_charged_cents: r.total_charged_cents,
        charged_to: r.charged_to,
        status: r.status
      }
    end
  end
end
