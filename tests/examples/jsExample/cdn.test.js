/* *********************************************************************
 * This Original Work is copyright of 51 Degrees Mobile Experts Limited.
 * Copyright 2019 51 Degrees Mobile Experts Limited, 5 Charlotte Close,
 * Caversham, Reading, Berkshire, United Kingdom RG4 7BY.
 *
 * This Original Work is licensed under the European Union Public Licence (EUPL)
 * v.1.2 and is subject to its terms as set out below.
 *
 * If a copy of the EUPL was not distributed with this file, You can obtain
 * one at https://opensource.org/licenses/EUPL-1.2.
 *
 * The 'Compatible Licences' set out in the Appendix to the EUPL (as may be
 * amended by the European Commission) shall be deemed incompatible for
 * the purposes of the Work and the provisions of the compatibility
 * clause in Article 5 of the EUPL shall not apply.
 *
 * If using the Work as, or as part of, a network application, by
 * including the attribution notice(s) required under Article 5 of the EUPL
 * in the end user terms of the application under an appropriate heading,
 * such notice(s) shall fulfill the requirements of that article.
 * ********************************************************************* */

const {Builder, By, until} = require('selenium-webdriver');
const chrome = require('selenium-webdriver/chrome');
const firefox = require('selenium-webdriver/firefox');
const edge = require('selenium-webdriver/edge');
const path = require('path');

const PageWaitMilliseconds = 10000;

let eOpts = new edge.Options();

// Opens index.html from a file, as the example says, and returns the width
// the page shows once the example's /overrides has answered.
async function shownWidth(driver) {
	try {
		const filePath =
			path.resolve('../../../examples/hash/jsExample/index.html');
		await driver.get('file://' + filePath);
		const value = await driver.wait(
			until.elementLocated(By.id('widthvalue')), PageWaitMilliseconds);
		return await value.getText();
	}
	finally {
		await driver.quit();
	}
}

// Check the JavaScript example works in a browser. NGINX must be running
// with the example configuration and the TAC data file, and the browsers
// and their drivers must be installed.
describe('Javascript tests', () => {
	// Chrome keeps no cookies for a page opened from a file, so /51D.js
	// cannot pass the width on, and the page shows the value the data
	// file holds for Chrome's User-Agent.
	test('Javascript in Chrome', async () => {
		let driver = await new Builder()
			.forBrowser('chrome')
			.setChromeOptions(new chrome.Options()
				.addArguments('--headless=new', '--no-sandbox'))
			.build();
		expect(await shownWidth(driver)).toMatch(/^(\d+|Unknown)$/);
	}, 20000);

	// Firefox keeps the cookie /51D.js sets, so the page shows the
	// browser's own screen width.
	test('Javascript in Firefox', async () => {
		let driver = await new Builder()
			.forBrowser('firefox')
			.setFirefoxOptions(new firefox.Options().addArguments('-headless'))
			.build();
		expect(await shownWidth(driver)).toMatch(/^\d+$/);
	}, 20000);
	
	// Edge 108 is currently has issues starting in headless mode.
	// This test will be reinstated once the problem is solved.
	// test('Javascript in Microsoft Edge', async () => {
	// 	let driver = await new Builder()
	// 		.forBrowser('MicrosoftEdge')
	// 		.setEdgeOptions(eOpts.headless())
	// 		.build();
	// 	await cdnTest(driver);
	// }, 20000);
});
