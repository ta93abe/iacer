const url = "https://aws.amazon.com/";

export async function handler(event) {
	try {
		const res = await fetch(url);
		console.info("status", res.status);
		return res.status;
	} catch (e) {
		console.error(e);
		return 500;
	}
};
