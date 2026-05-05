module Api
  class UsageController < ApplicationController
    # GET /api/usage/log
    def log
      records = CapabilityLog.for_actor(@current_actor_id).order(invoked_at: :desc)
      records = records.for_provider(params[:provider])     if params[:provider].present?
      records = records.for_capability(params[:capability]) if params[:capability].present?
      records = records.where(status: params[:status])      if params[:status].present?
      records = records.where(invoked_at: date_range)       if params[:start_date].present?

      page     = (params[:page] || 1).to_i
      per_page = 50
      total    = records.count
      records  = records.offset((page - 1) * per_page).limit(per_page)

      render json: {
        records: records.map { |r| format_record(r) },
        total: total,
        page: page,
        pages: (total / per_page.to_f).ceil
      }
    end

    # GET /api/usage/summary
    def summary
      all     = CapabilityLog.for_actor(@current_actor_id)
      month   = all.this_month

      last_12 = (0..11).map do |i|
        start  = i.months.ago.beginning_of_month
        finish = i.months.ago.end_of_month
        {
          month:       start.strftime("%b %Y"),
          total_cents: all.where(invoked_at: start..finish).sum(:total_charged_cents)
        }
      end.reverse

      render json: {
        this_month_total_cents:     month.sum(:total_charged_cents),
        this_month_raw_cost_cents:  month.sum(:raw_cost_cents),
        this_month_markup_cents:    month.sum(:markup_cents),
        all_time_total_cents:       all.sum(:total_charged_cents),
        call_count_this_month:      month.count,
        breakdown_by_capability:    month.group(:capability).sum(:total_charged_cents),
        breakdown_by_provider:      month.group(:provider).sum(:total_charged_cents),
        last_12_months:             last_12
      }
    end

    private

    def date_range
      start_date = Date.parse(params[:start_date])
      end_date   = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.today
      start_date.beginning_of_day..end_date.end_of_day
    end

    def format_record(r)
      {
        id:                  r.id,
        capability:          r.capability,
        version:             r.version,
        provider:            r.provider,
        provider_request_id: r.provider_request_id,
        raw_cost_cents:      r.raw_cost_cents,
        markup_cents:        r.markup_cents,
        total_charged_cents: r.total_charged_cents,
        charged_to:          r.charged_to,
        status:              r.status,
        error_code:          r.error_code,
        metadata:            r.metadata_json ? JSON.parse(r.metadata_json) : {},
        invoked_at:          r.invoked_at,
        completed_at:        r.completed_at
      }
    end
  end
end
