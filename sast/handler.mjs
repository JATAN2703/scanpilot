// SAST stage of the ScanPilot pipeline (called by Step Functions).
// Same contract as src/stage_stub.py: write the findings JSON to S3, return its key.
import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { scanZip } from './scan.mjs';

const s3 = new S3Client({});
const MAX_UPLOAD_SIZE = 50 * 1024 * 1024; // 50 MB zip

const uploadInvalid = (message) => {
  const err = new Error(message);
  err.name = 'UploadInvalid'; // the state machine doesn't retry this one
  return err;
};

export const handler = async (event) => {
  const { customer_id, job_id, bucket } = event;
  const codeKey = event.code_key || `uploads/${customer_id}/${job_id}/code.zip`;

  if (event.force_fail_step === 'sast') {
    const err = new Error('simulated sast failure (test run)');
    err.name = 'SimulatedStageError';
    throw err;
  }

  const obj = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: codeKey }));
  if (obj.ContentLength > MAX_UPLOAD_SIZE) {
    throw uploadInvalid(`upload is ${obj.ContentLength} bytes, the limit is ${MAX_UPLOAD_SIZE}`);
  }
  const zip = Buffer.from(await obj.Body.transformToByteArray());

  let result;
  try {
    result = scanZip(zip);
  } catch (err) {
    throw uploadInvalid(err.message);
  }

  const output = {
    job_id,
    stage: 'sast',
    generated_at: new Date().toISOString(),
    ...result
  };
  const key = `findings/${customer_id}/${job_id}/sast.json`;
  await s3.send(new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    Body: JSON.stringify(output, null, 2),
    ContentType: 'application/json'
  }));

  console.log(`job ${job_id}: scanned ${result.summary.filesScanned} files, ` +
    `${result.summary.totalVulnerabilities} findings (${result.summary.high} high)`);
  return { stage: 'sast', output_key: key, summary: result.summary };
};
