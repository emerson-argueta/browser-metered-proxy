module Api
  class UsageController < ApplicationController
    # GET /api/usage/log
    def log
      records = UsageRecord.where(user_id: @current_user_id).order(called_at: :desc)
      records = records.where(provider: params[:provider]) if params[:provider].present?
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
      all_records = UsageRecord.where(user_id: @current_user_id)
      this_month = all_records.where(called_at: Time.current.beginning_of_month..)

      by_type = this_month.group(:call_type).sum(:total_charged_cents)
      by_provider = this_month.group(:provider).sum(:total_charged_cents)
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
        by_provider: by_provider,
        last_12_months: last_12
      }
    end

    # POST /api/billing/usage
    # Called by the browser client to log usage after a proxied call
    def record
      rec = UsageRecord.create!(
        user_id: @current_user_id,
        provider: params[:provider],
        call_type: params.require(:call_type),
        external_request_id: params[:external_request_id],
        raw_cost_cents: params[:raw_cost_cents].to_i,
        markup_cents: params[:markup_cents].to_i,
        total_charged_cents: params[:total_charged_cents].to_i,
        charged_to: params[:charged_to] || "user",
        status: params[:status] || "success",
        called_at: params[:called_at] || Time.current,
        metadata_json: params[:metadata]&.to_json,
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
        provider: r.provider,
        call_type: r.call_type,
        external_request_id: r.external_request_id,
        metadata: r.metadata_json ? JSON.parse(r.metadata_json) : {},
        raw_cost_cents: r.raw_cost_cents,
        markup_cents: r.markup_cents,
        total_charged_cents: r.total_charged_cents,
        charged_to: r.charged_to,
        status: r.status
      }
    end
  end
end
