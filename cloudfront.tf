module "cdn" {
  source              = "terraform-aws-modules/cloudfront/aws"
  create_distribution = var.enable_cloudfront

  aliases = ["sandbox.skawstf.com"]

  comment             = "CloudFront for ezwel sandbox"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false

  # create_origin_access_identity = true
  # origin_access_identities = {
  #   s3_bucket_one = "My awesome CloudFront can access"
  # }

  origin = {
    alb-eks-ingress = {
      domain_name = "alb-ezwel-sandbox-ingress-970457490.us-west-2.elb.amazonaws.com"
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = "alb-eks-ingress"
    viewer_protocol_policy = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = true
  }

  # ordered_cache_behavior = [
  #   {
  #     path_pattern           = "/static/*"
  #     target_origin_id       = "s3_one"
  #     viewer_protocol_policy = "redirect-to-https"

  #     allowed_methods = ["GET", "HEAD", "OPTIONS"]
  #     cached_methods  = ["GET", "HEAD"]
  #     compress        = true
  #     query_string    = true
  #   }
  # ]

  viewer_certificate = {
    acm_certificate_arn = "arn:aws:acm:us-east-1:533616270150:certificate/ea0f5caa-823b-44be-810d-3e4d18212433"
    ssl_support_method  = "sni-only"
  }
}
