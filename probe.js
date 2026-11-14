// Opens the JavaScript example page from a file, as the example says, in
// headless Chrome and Firefox, and prints what each shows.
const {Builder} = require('selenium-webdriver');
const chrome = require('selenium-webdriver/chrome');
const firefox = require('selenium-webdriver/firefox');
const logging = require('selenium-webdriver/lib/logging');
const path = require('path');

(async () => {
	const file = 'file://' + path.resolve(process.argv[2]);
	for (const name of ['chrome', 'firefox']) {
		let driver;
		try {
			let builder = new Builder().forBrowser(name);
			if (name === 'chrome') {
				const prefs = new logging.Preferences();
				prefs.setLevel(logging.Type.BROWSER, logging.Level.ALL);
				builder = builder.setChromeOptions(new chrome.Options()
					.addArguments('--headless=new', '--no-sandbox')
					.setLoggingPrefs(prefs));
			} else {
				builder = builder.setFirefoxOptions(
					new firefox.Options().addArguments('-headless'));
			}
			driver = await builder.build();
			await driver.get(file);
			await driver.sleep(5000);
			const text = await driver.executeScript('return document.body.innerText');
			const cookie = await driver.executeScript('return document.cookie');
			const width = await driver.executeScript('return screen.width');
			console.log(`${name} body: ${JSON.stringify(text)}`);
			console.log(`${name} cookie: ${JSON.stringify(cookie)}, screen.width ${width}`);
			if (name === 'chrome') {
				for (const entry of await driver.manage().logs().get(logging.Type.BROWSER)) {
					console.log(`${name} console: ${entry.message}`);
				}
			}
		} catch (e) {
			console.log(`${name} error: ${e}`);
		} finally {
			if (driver) {
				await driver.quit();
			}
		}
	}
})();
