# After every plan and apply, fetch the page through the load balancer the way
# a user would (hashicorp/http provider). A failure shows up as a warning.
check "site_up" {
  data "http" "site" {
    url = "http://${module.web.alb_dns_name}/"

    # Apply already waits for healthy servers (min_elb_capacity), so this only
    # covers a short DNS delay. Kept short: a failing check retries on every plan.
    retry {
      attempts     = 6
      min_delay_ms = 5000
      max_delay_ms = 5000
    }
  }

  assert {
    condition     = data.http.site.status_code == 200
    error_message = "${data.http.site.url} returned HTTP ${data.http.site.status_code}, expected 200."
  }
}
