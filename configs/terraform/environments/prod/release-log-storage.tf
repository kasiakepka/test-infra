# Release Test Log Storage Configuration
# This bucket stores logs from release tests.

import {
  to = google_storage_bucket.release_test_logs
  id = "kyma_release_test_logs"
}

resource "google_storage_bucket" "release_test_logs" {
  name          = "kyma_release_test_logs"
  location      = "europe-central2"
  force_destroy = false

  uniform_bucket_level_access = true
}

# This service account uploads release test logs to this bucket.
resource "google_storage_bucket_iam_member" "release_log_uploader_access" {
  bucket = google_storage_bucket.release_test_logs.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:release-log-uploader@sap-kyma-prow.iam.gserviceaccount.com"
}
