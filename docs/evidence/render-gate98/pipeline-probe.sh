mkdir -p reports
if python -c "print('EXPECTED_RENDER_PROBE_FAILURE'); raise SystemExit(23)" | tee reports/pipeline-failure.log; then
  echo 'A failed renderer was hidden by log capture'
  exit 1
else
  probe_status=$?
  test "$probe_status" -eq 23
fi
