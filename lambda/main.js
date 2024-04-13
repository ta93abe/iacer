const url = "https://aws.amazon.com/";

export const handler = async (event) => {
	try {
		// fetch is available with Node.js 18
		const res = await fetch(url);
		console.info("status", res.status);
		return res.status;
	} catch (e) {
		console.error(e);
		return 500;
	}
};
