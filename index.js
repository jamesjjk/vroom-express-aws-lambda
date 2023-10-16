const serverlessExpress = require('@vendia/serverless-express');
const app = require('./src/index');
exports.handler = serverlessExpress({app});

function mapHttpRequest({event}) {
  console.log(event);
  let body = event.body || {};
  try {
    body = JSON.parse(event.body);
  } catch (er) {}
  return {
    body: body,
    headers: event.headers || {},
    method: event.httpMethod || 'GET',
    path: event.path || '/health',
  };
}

function mapResponse({statusCode, body, headers, isBase64Encoded}) {
  return {
    body,
    headers,
    isBase64Encoded,
    statusCode,
  };
}

exports.handler = serverlessExpress({
  app,
  eventSource: {
    getRequest: mapHttpRequest,
    getResponse: mapResponse,
  },
});
