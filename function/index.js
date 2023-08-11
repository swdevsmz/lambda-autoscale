exports.handler = async (event, context) => {
  console.log("Event: ", JSON.stringify(event));

  return {
    status: 200,
    body: `Hello world!`,
  };
};
