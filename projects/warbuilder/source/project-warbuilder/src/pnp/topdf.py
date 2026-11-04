import asyncio, sys
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page()
        await pg.goto('file:///home/claude/wzdb6/pnp/pnp.html'); await pg.wait_for_timeout(500)
        await pg.pdf(path='/home/claude/wzdb6/pnp/Warzone-Deckbuilder-Print-and-Play.pdf', format='Letter', print_background=True, margin={'top':'0','bottom':'0','left':'0','right':'0'})
        await b.close()
asyncio.run(main())
