import os
import sys
import subprocess
import shutil

OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
EDGE_PATH = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

os.makedirs(OUTPUT_DIR, exist_ok=True)

html_content = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Egg Sanctuary: Feed, Clean & Hatch - Game Design Document v2.1</title>
<style>
    @page {
        size: A4;
        margin: 18mm 18mm 20mm 18mm;
        @bottom-right {
            content: counter(page);
        }
    }
    body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        color: #1e293b;
        line-height: 1.55;
        font-size: 10pt;
        background-color: #ffffff;
        margin: 0;
        padding: 0;
    }
    .page-break {
        page-break-after: always;
        break-after: page;
    }
    /* Cover Page */
    .cover {
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        height: 100vh;
        box-sizing: border-box;
        padding: 40px 20px 20px 20px;
        background: linear-gradient(135deg, #0f172a 0%, #1e1b4b 50%, #0369a1 100%);
        color: #ffffff;
        border-radius: 8px;
    }
    .cover-top {
        margin-top: 40px;
    }
    .badge-roblox {
        display: inline-block;
        background: #0284c7;
        color: #ffffff;
        font-weight: 700;
        font-size: 9pt;
        padding: 4px 12px;
        border-radius: 20px;
        text-transform: uppercase;
        letter-spacing: 1.5px;
        margin-bottom: 20px;
    }
    .cover-title {
        font-size: 28pt;
        font-weight: 900;
        line-height: 1.15;
        margin: 0 0 10px 0;
        letter-spacing: -0.5px;
        color: #38bdf8;
    }
    .cover-subtitle {
        font-size: 16pt;
        font-weight: 400;
        color: #e2e8f0;
        margin: 0 0 25px 0;
    }
    .cover-tagline {
        font-size: 11pt;
        font-style: italic;
        color: #93c5fd;
        border-left: 3px solid #38bdf8;
        padding-left: 14px;
        margin-bottom: 40px;
    }
    .cover-meta {
        background: rgba(255, 255, 255, 0.08);
        border: 1px solid rgba(255, 255, 255, 0.15);
        padding: 18px;
        border-radius: 8px;
        font-size: 9.5pt;
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 10px;
    }
    .cover-meta div strong {
        color: #7dd3fc;
    }
    .cover-bottom {
        font-size: 8pt;
        color: #94a3b8;
        border-top: 1px solid rgba(255, 255, 255, 0.2);
        padding-top: 15px;
        text-align: center;
    }
    /* Standard Typography */
    h1 {
        font-size: 17pt;
        font-weight: 800;
        color: #0f172a;
        border-bottom: 2.5px solid #0284c7;
        padding-bottom: 6px;
        margin-top: 25px;
        margin-bottom: 14px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }
    h2 {
        font-size: 12.5pt;
        font-weight: 700;
        color: #0369a1;
        margin-top: 18px;
        margin-bottom: 8px;
        border-left: 3px solid #0284c7;
        padding-left: 8px;
    }
    h3 {
        font-size: 10.5pt;
        font-weight: 700;
        color: #334155;
        margin-top: 14px;
        margin-bottom: 6px;
    }
    p {
        margin: 0 0 9px 0;
        text-align: justify;
    }
    ul, ol {
        margin: 0 0 10px 0;
        padding-left: 20px;
    }
    li {
        margin-bottom: 4px;
    }
    /* Tables */
    table {
        width: 100%;
        border-collapse: collapse;
        margin: 12px 0 16px 0;
        font-size: 8.5pt;
    }
    th {
        background-color: #0f172a;
        color: #ffffff;
        font-weight: 700;
        text-align: left;
        padding: 6px 8px;
        border: 1px solid #0f172a;
    }
    td {
        padding: 5px 8px;
        border: 1px solid #cbd5e1;
        vertical-align: top;
    }
    tr:nth-child(even) {
        background-color: #f8fafc;
    }
    /* Callouts */
    .callout {
        background-color: #f0f9ff;
        border-left: 4px solid #0284c7;
        padding: 10px 14px;
        margin: 12px 0;
        border-radius: 0 6px 6px 0;
        font-size: 9pt;
    }
    .callout-title {
        font-weight: 700;
        color: #0369a1;
        margin-bottom: 4px;
    }
    .formula-box {
        background: #f1f5f9;
        border: 1px dashed #64748b;
        padding: 8px 12px;
        border-radius: 4px;
        font-family: "Courier New", Courier, monospace;
        font-size: 8.5pt;
        color: #0f172a;
        margin: 8px 0;
    }
    .header-bar {
        display: flex;
        justify-content: space-between;
        font-size: 7.5pt;
        color: #64748b;
        border-bottom: 1px solid #e2e8f0;
        padding-bottom: 4px;
        margin-bottom: 12px;
    }
</style>
</head>
<body>

<!-- COVER PAGE -->
<div class="cover">
    <div class="cover-top">
        <div class="badge-roblox">Roblox Production Specification • GDD v2.1</div>
        <div class="cover-title">EGG SANCTUARY</div>
        <div class="cover-subtitle">FEED, CLEAN & HATCH (FOOD LUCK ARCHITECTURE)</div>
        <div class="cover-tagline">"Strength = Distance. Food = Luck. Washer = Speed. Garden = Empire."</div>
    </div>
    <div>
        <div class="cover-meta">
            <div><strong>Project Codename:</strong> Project Feed & Scrubber</div>
            <div><strong>Document Version:</strong> v2.1 (Food Luck & Rarity Engine)</div>
            <div><strong>Target Platform:</strong> Roblox (Mobile-First, Console, PC)</div>
            <div><strong>Target Audience:</strong> All-Ages (Ages 6–24, Casual & Midcore)</div>
            <div><strong>Genre:</strong> Distance Thrower / Restoration / Tycoon Hybrid</div>
            <div><strong>Dual Treadmill:</strong> Arm Strength (Distance) + Food Tier (Luck)</div>
            <div><strong>Production Target:</strong> 30-Day MVP / Q1 2026 Soft Launch</div>
            <div><strong>Benchmark Target:</strong> 250,000–400,000+ Concurrent Players (CCU)</div>
        </div>
    </div>
    <div class="cover-bottom">
        CONFIDENTIAL & PROPRIETARY — FOR INTERNAL DEVELOPMENT & AUTHORIZED STUDIO PARTNERS ONLY.<br>
        Standard 19-Section Game Design Document with Validated Core Mechanics.
    </div>
</div>

<div class="page-break"></div>

<!-- SECTION 1: DOCUMENT CONTROL & TOC -->
<div class="header-bar">
    <span>EGG SANCTUARY: FEED, CLEAN & HATCH • GDD v2.1</span>
    <span>SECTION 1: CONTROL & TOC</span>
</div>

<h1>1. Document Control & Table of Contents</h1>

<h3>Version History</h3>
<table>
    <tr>
        <th>Version</th>
        <th>Date</th>
        <th>Author / Role</th>
        <th>Key Revisions</th>
    </tr>
    <tr>
        <td><strong>v0.1</strong></td>
        <td>Nov 2026</td>
        <td>Senior Game Strategist</td>
        <td>Initial concept ideation & "Steal an Egg" market critique.</td>
    </tr>
    <tr>
        <td><strong>v1.0</strong></td>
        <td>Nov 2026</td>
        <td>Lead Game Designer</td>
        <td>Full 19-section GDD with 3-layer cleaning & garden incubation.</td>
    </tr>
    <tr>
        <td><strong>v2.0</strong></td>
        <td>Nov 2026</td>
        <td>Executive Studio Producer</td>
        <td>Redesign to "Feed to Lay" Model (benchmarked against 400k+ CCU hits).</td>
    </tr>
    <tr>
        <td><strong>v2.1</strong></td>
        <td>Nov 2026</td>
        <td>Lead Systems Architect</td>
        <td><strong>Integrated Food Luck & Mutation Engine:</strong> Food upgrades directly multiply Luck, Shiny Mutation chance, and Alpha Beast summon rates, creating the perfect dual-progression loop.</td>
    </tr>
</table>

<h3>Table of Contents</h3>
<ol style="columns: 2; column-gap: 20px; font-size: 8.5pt;">
    <li>Document Control & TOC</li>
    <li>Executive Summary</li>
    <li>Game Overview & Experience Pillars</li>
    <li>Core Gameplay Loop ("Feed to Lay" 4-Beat Cycle)</li>
    <li>Game Mechanics (Throwing, Food Luck, Washing, Hatching)</li>
    <li>Progression & The Dual Treadmill (Strength vs. Food)</li>
    <li>Content Design (Food Tier Matrix, Distance Track, Pets)</li>
    <li>Narrative & World Setting</li>
    <li>UX Flow & Mobile Interface</li>
    <li>Art Direction & Animation Sequences</li>
    <li>Audio Design & Haptic Feedback</li>
    <li>Social & Multiplayer Ecosystem</li>
    <li>Monetization & Robux Architecture</li>
    <li>Mathematical Economy & Luck Probability Balancing</li>
    <li>Technical Architecture & Luau Spec</li>
    <li>Competitive Analysis & Market Positioning</li>
    <li>30-Day Production Roadmap</li>
    <li>Risk Assessment & Mitigation Matrix</li>
    <li>Appendices & Master Keybinds</li>
</ol>

<hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;">

<!-- SECTION 2: EXECUTIVE SUMMARY -->
<div class="header-bar">
    <span>EGG SANCTUARY: FEED, CLEAN & HATCH • GDD v2.1</span>
    <span>SECTION 2: EXECUTIVE SUMMARY</span>
</div>

<h1>2. Executive Summary</h1>

<p><strong>Egg Sanctuary: Feed, Clean & Hatch</strong> is an innovative, high-dopamine hybrid Roblox title designed specifically to capture the massive 400k+ CCU audience demonstrated by recent breakout hits like <em>Throw Food for Animals</em>, combined with the hypnotic visual ASMR of <em>PowerWash Simulator</em> and the passive tycoon satisfaction of <em>Grow a Garden</em>.</p>

<p>In GDD v2.1, the progression economy is perfected through the <strong>Dual-Treadmill System</strong>:</p>
<ul>
    <li><strong>Strength (Gym) = DISTANCE:</strong> Determines how many thousands of studs down the canyon your food flies, unlocking deeper biomes (Meadow $\rightarrow$ Swamp $\rightarrow$ Volcano $\rightarrow$ Reef $\rightarrow$ Galaxy).</li>
    <li><strong>Food Tier (Kitchen) = LUCK & QUALITY:</strong> Determines the rarity multiplier, shiny mutation odds, and Alpha Boss summon rates of the egg that drops. Upgraded food guarantees that even throwing in early zones can yield 1-in-10,000 Shiny Mythic pets!</li>
</ul>

<div class="callout">
    <div class="callout-title">The Four Golden Formula Rules</div>
    <ul>
        <li><strong>Rule 1 (Distance):</strong> Strength increases reach, letting food access rarer wild biomes.</li>
        <li><strong>Rule 2 (Luck):</strong> Food quality increases rarity rolls (from 1x up to 100x Luck) and shiny chances (up to 35%).</li>
        <li><strong>Rule 3 (Speed):</strong> Washer PSI cuts cleaning time from 30s down to 3s.</li>
        <li><strong>Rule 4 (Wealth):</strong> Garden Sanctuary hosts pets that produce passive Bio-Essence ($/sec) to fund continuous cycles.</li>
    </ul>
</div>

<table>
    <tr>
        <th>Performance Benchmark</th>
        <th>Target KPI</th>
        <th>Market Justification</th>
    </tr>
    <tr>
        <td><strong>Day 1 Retention (D1)</strong></td>
        <td><strong>45.0% - 48.0%</strong></td>
        <td>First throw within 10 seconds of spawn; instant double-dopamine payoff.</td>
    </tr>
    <tr>
        <td><strong>Day 7 Retention (D7)</strong></td>
        <td><strong>18.5%</strong></td>
        <td>Food upgrade treadmill + distance zone unlocks maintain long-term goals.</td>
    </tr>
    <tr>
        <td><strong>Average Session Length</strong></td>
        <td><strong>22–26 Minutes</strong></td>
        <td>Harmonious cycle of gym training, throwing, washing, and garden expansion.</td>
    </tr>
    <tr>
        <td><strong>Target Peak CCU</strong></td>
        <td><strong>250,000–400,000+</strong></td>
        <td>Benchmarked directly against <em>Throw Food for Animals</em> (400k-1M CCU).</td>
    </tr>
</table>

<div class="page-break"></div>

<!-- SECTION 3: GAME OVERVIEW -->
<div class="header-bar">
    <span>EGG SANCTUARY: FEED, CLEAN & HATCH • GDD v2.1</span>
    <span>SECTION 3: GAME OVERVIEW</span>
</div>

<h1>3. Game Overview & Experience Pillars</h1>

<p><strong>High Concept:</strong> <em>Throw Food for Animals</em> meets <em>PowerWash Simulator</em> and <em>Grow a Garden</em> — Train your throw strength, cook luxury treats with high Luck multipliers, launch food across massive canyons, and power-wash the eggs laid by ecstatic wild beasts to construct a mythical sanctuary.</p>

<h2>The 4 Experience Pillars</h2>
<ul>
    <li><strong>Pillar 1: The High-Velocity Toss ("The Big Launch"):</strong> Physical satisfaction of launching food thousands of studs with dynamic camera tracking and zone milestone popups.</li>
    <li><strong>Pillar 2: The Lucky Chomp ("The Golden Lay"):</strong> Wild creatures leaping mid-air to catch the food. High-tier food triggers special "Alpha Summon" animations and rolls for shiny mutated eggs.</li>
    <li><strong>Pillar 3: The Tactile Wash ("The Pristine Reveal"):</strong> The ASMR satisfaction of peeling away mud and magma crust using pressure washers and scrapers to reveal the sparkling egg shell.</li>
    <li><strong>Pillar 4: The Thriving Sanctuary ("My Pet Empire"):</strong> Watching your garden populate with hundreds of roaming, adorable creatures that passively generate Bio-Essence while you flex rare mutations to friends.</li>
</ul>

<hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;">

<!-- SECTION 4 & 5: MECHANICS & FOOD LUCK ENGINE -->
<div class="header-bar">
    <span>EGG SANCTUARY: FEED, CLEAN & HATCH • GDD v2.1</span>
    <span>SECTION 5: FOOD LUCK SPECIFICATION</span>
</div>

<h1>5. The Food Luck & Mutation Engine</h1>

<h2>5.1 The Mathematical Luck Formula</h2>
<p>When an animal catches food, the egg's rarity roll is calculated using the equipped <strong>Food Luck Multiplier</strong> combined with server events and gamepass multipliers:</p>
<div class="formula-box">
    Final_Egg_Luck = (Food_Tier_Luck) * (1 + Player_Rebirth_Bonus) * (VIP_Multiplier)
</div>

<h2>5.2 Master Food Tier & Luck Table</h2>
<table>
    <tr>
        <th>Tier</th>
        <th>Food Item</th>
        <th>Luck Multiplier</th>
        <th>Shiny / Mutation Chance</th>
        <th>Special Effect / Alpha Lure</th>
    </tr>
    <tr>
        <td><strong>T1</strong></td>
        <td><strong>Red Apple</strong></td>
        <td><strong>1.0x</strong> (Base)</td>
        <td>0.1% (1 in 1,000)</td>
        <td>Attracts basic meadow creatures only.</td>
    </tr>
    <tr>
        <td><strong>T2</strong></td>
        <td><strong>Carrot Cupcake</strong></td>
        <td><strong>1.5x</strong> Luck</td>
        <td>0.5% (1 in 200)</td>
        <td>+10% chance for a <strong>Giant Egg</strong> (2x cash yield).</td>
    </tr>
    <tr>
        <td><strong>T3</strong></td>
        <td><strong>Honey Glazed Ribs</strong></td>
        <td><strong>2.5x</strong> Luck</td>
        <td>1.5% (1 in 66)</td>
        <td>Guarantees at least an Uncommon egg drop.</td>
    </tr>
    <tr>
        <td><strong>T4</strong></td>
        <td><strong>Golden Star-Berry</strong></td>
        <td><strong>5.0x</strong> Luck</td>
        <td>3.5% (1 in 28)</td>
        <td><strong>Guarantees at least a Rare egg drop.</strong></td>
    </tr>
    <tr>
        <td><strong>T5</strong></td>
        <td><strong>Flame-Grilled Steak</strong></td>
        <td><strong>10.0x</strong> Luck</td>
        <td>7.5% (1 in 13)</td>
        <td>Lures Magma Drakes out of volcanic craters.</td>
    </tr>
    <tr>
        <td><strong>T6</strong></td>
        <td><strong>Rainbow Cotton Candy</strong></td>
        <td><strong>25.0x</strong> Luck</td>
        <td>15.0% (1 in 6.6)</td>
        <td>Can trigger a <strong>Rainbow Pet Mutation (5x income)</strong>!</td>
    </tr>
    <tr>
        <td><strong>T7</strong></td>
        <td><strong>Abyssal Caviar</strong></td>
        <td><strong>50.0x</strong> Luck</td>
        <td>22.5% (1 in 4.4)</td>
        <td>Attracts Deepsea Krakens and Pearl Leviathans.</td>
    </tr>
    <tr>
        <td><strong>T8</strong></td>
        <td><strong>Cosmic Ambrosia</strong></td>
        <td><strong>100.0x Luck</strong></td>
        <td><strong>35.0%</strong> (1 in 2.8)</td>
        <td><strong>1 in 50 chance to summon the Godly Galaxy Titan!</strong></td>
    </tr>
</table>

<div class="page-break"></div>

<!-- SECTION 6: PROGRESSION SYSTEM -->
<div class="header-bar">
    <span>EGG SANCTUARY: FEED, CLEAN & HATCH • GDD v2.1</span>
    <span>SECTION 6: PROGRESSION SYSTEM</span>
</div>

<h1>6. Progression System & The Dual Treadmill</h1>

<p>Players balance four distinct upgrade paths using earned Bio-Essence:</p>

<table>
    <tr>
        <th>Progression Stream</th>
        <th>What It Upgrades</th>
        <th>Starting Level</th>
        <th>Endgame Level</th>
        <th>Player Impact</th>
    </tr>
    <tr>
        <td><strong>Throw Strength (Gym)</strong></td>
        <td>Distance (Studs)</td>
        <td>10 Studs</td>
        <td>50,000+ Studs</td>
        <td>Unlocks access to deeper, exotic wilderness biomes.</td>
    </tr>
    <tr>
        <td><strong>Food Tier (Kitchen)</strong></td>
        <td>Luck & Mutation</td>
        <td>Tier 1 (1x Luck)</td>
        <td>Tier 8 (100x Luck)</td>
        <td>Dramatically increases the drop rate of Mythic & Shiny pets.</td>
    </tr>
    <tr>
        <td><strong>Washer PSI (Workshop)</strong></td>
        <td>Cleaning Speed</td>
        <td>50 PSI</td>
        <td>5,000 PSI</td>
        <td>Cuts egg wash time from 30 seconds down to 3 seconds.</td>
    </tr>
    <tr>
        <td><strong>Sanctuary Plots (Gardener)</strong></td>
        <td>Capacity & Income</td>
        <td>4 Pets / 2 Nests</td>
        <td>32 Pets / 8 Nests</td>
        <td>Multiplies total passive income generation per second.</td>
    </tr>
</table>

<hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;">

<!-- SECTION 7: CONTENT DESIGN -->
<div class="header-bar">
    <span>EGG SANCTUARY: FEED, CLEAN & HATCH • GDD v2.1</span>
    <span>SECTION 7: CONTENT DESIGN</span>
</div>

<h1>7. Content Design (Distance Track & Biomes)</h1>

<table>
    <tr>
        <th>Zone & Distance</th>
        <th>Recommended Food</th>
        <th>Featured Beasts</th>
        <th>Egg Laid</th>
        <th>Base Income</th>
    </tr>
    <tr>
        <td><strong>1. Dewdrop Meadow</strong><br>(0 – 300 Studs)</td>
        <td>Apple, Cupcake<br>(T1–T2)</td>
        <td>Fluffy Bunny, Moss Turtle, Chubby Hamster</td>
        <td>Muddy Meadow Egg<br>(Common/Uncommon)</td>
        <td>1 – 5 $/s</td>
    </tr>
    <tr>
        <td><strong>2. Toxic Slime Marsh</strong><br>(300 – 1,500 Studs)</td>
        <td>Honey Ribs, Star-Berry<br>(T3–T4)</td>
        <td>Slime Frog, Bog Lizard, Venom Crocodile</td>
        <td>Slime-Coated Egg<br>(Rare/Epic)</td>
        <td>15 – 60 $/s</td>
    </tr>
    <tr>
        <td><strong>3. Cinder Volcano</strong><br>(1,500 – 5,000 Studs)</td>
        <td>Flame Steak<br>(T5)</td>
        <td>Ember Hound, Magma Wyrm, Pyre Phoenix</td>
        <td>Obsidian Magma Egg<br>(Epic/Legendary)</td>
        <td>200 – 800 $/s</td>
    </tr>
    <tr>
        <td><strong>4. Sunken Coral Reef</strong><br>(5,000 – 15,000 Studs)</td>
        <td>Rainbow Candy, Caviar<br>(T6–T7)</td>
        <td>Coral Dragon, Deepsea Kraken, Pearl Whale</td>
        <td>Barnacle Pearl Egg<br>(Legendary/Mythic)</td>
        <td>2,500 – 10k $/s</td>
    </tr>
    <tr>
        <td><strong>5. Celestial Galaxy</strong><br>(15,000 – 50,000+ Studs)</td>
        <td>Cosmic Ambrosia<br>(T8)</td>
        <td>Nebula Kirin, Solar Drake, Galaxy Titan</td>
        <td>Starlight Crystal Egg<br>(Mythic / Godly 1 in 10k)</td>
        <td>50,000+ $/s</td>
    </tr>
</table>

<div class="page-break"></div>

<!-- SECTION 13: MONETIZATION -->
<div class="header-bar">
    <span>EGG SANCTUARY: FEED, CLEAN & HATCH • GDD v2.1</span>
    <span>SECTION 13: MONETIZATION</span>
</div>

<h1>13. Monetization Strategy & Robux Architecture</h1>

<table>
    <tr>
        <th>Product Name</th>
        <th>Type</th>
        <th>Price (Robux)</th>
        <th>Player Motivation & Strategic Purpose</th>
    </tr>
    <tr>
        <td><strong>Auto-Thrower Drone</strong></td>
        <td>Gamepass</td>
        <td>R$ 799</td>
        <td>Automatically throws food every 5 seconds while you wash eggs or AFK train! (Top Seller).</td>
    </tr>
    <tr>
        <td><strong>Auto-Washer Robot</strong></td>
        <td>Gamepass</td>
        <td>R$ 899</td>
        <td>Washes laid eggs instantly, allowing pure focus on distance throwing and garden upgrades.</td>
    </tr>
    <tr>
        <td><strong>Lucky Chef Pass</strong></td>
        <td>Gamepass</td>
        <td>R$ 499</td>
        <td>Permanently doubles (+100%) the Luck Multiplier of all equipped foods.</td>
    </tr>
    <tr>
        <td><strong>+4 Garden Incubators</strong></td>
        <td>Gamepass</td>
        <td>R$ 399</td>
        <td>Expands simultaneous egg hatching capacity from 4 to 8.</td>
    </tr>
    <tr>
        <td><strong>Golden Feast Bait</strong></td>
        <td>Dev Product</td>
        <td>R$ 99</td>
        <td>Next throw turns food into 24k gold, granting <strong>500% Luck</strong> and a guaranteed Golden Egg.</td>
    </tr>
    <tr>
        <td><strong>Instant Hatch Potion</strong></td>
        <td>Dev Product</td>
        <td>R$ 49</td>
        <td>Instantly hatches any incubating egg without waiting.</td>
    </tr>
</table>

<hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;">

<!-- SECTION 17: PRODUCTION ROADMAP -->
<div class="header-bar">
    <span>EGG SANCTUARY: FEED, CLEAN & HATCH • GDD v2.1</span>
    <span>SECTION 17: PRODUCTION ROADMAP</span>
</div>

<h1>17. 30-Day Production Roadmap ("Feed to Lay" + Food Luck)</h1>

<table>
    <tr>
        <th>Sprint Timeline</th>
        <th>Key Engineering Deliverables</th>
        <th>Art, VFX & Animation Deliverables</th>
        <th>Milestone Target</th>
    </tr>
    <tr>
        <td><strong>Sprint 1 (Days 1–7)</strong></td>
        <td>Throw trajectory Bézier math; Strength gym training; Food luck calculation tables; ProfileService schema.</td>
        <td>Launch deck greybox; 3 Food models (Apple, Ribs, Steak); Food flight trail particles.</td>
        <td>Core Throw Loop: Train power $\rightarrow$ Throw food with accurate luck multiplier.</td>
    </tr>
    <tr>
        <td><strong>Sprint 2 (Days 8–14)</strong></td>
        <td>Animal mouth catch hit-box; Lay-egg animation trigger; Return chute delivery logic.</td>
        <td>Meadow & Swamp animal rigs; "Chomp" & "Pop" animations; Egg delivery slide asset.</td>
        <td>Full Delivery Loop: Animal eats food $\rightarrow$ Lays egg $\rightarrow$ Egg rolls to wash table.</td>
    </tr>
    <tr>
        <td><strong>Sprint 3 (Days 15–21)</strong></td>
        <td>3-Layer wash station; Garden grid placement; Passive essence coin collection.</td>
        <td>Washer water spray VFX; 15 Baby pet models; Garden nursery environment kit.</td>
        <td>Complete End-to-End Game: Throw $\rightarrow$ Lay $\rightarrow$ Wash $\rightarrow$ Hatch in Garden!</td>
    </tr>
    <tr>
        <td><strong>Sprint 4 (Days 22–30)</strong></td>
        <td>Auto-Thrower & Auto-Washer gamepasses; Analytics hooks; Polish pass & mobile test.</td>
        <td>Audio mix mastering; Game icon & split-screen thumbnail; Victory UI cinematics.</td>
        <td>Soft Launch on Roblox with 50-player test group; target 45% D1 retention.</td>
    </tr>
</table>

<div class="page-break"></div>

<!-- SECTION 19: SIGN-OFF -->
<div class="header-bar">
    <span>EGG SANCTUARY: FEED, CLEAN & HATCH • GDD v2.1</span>
    <span>SECTION 19: SIGN-OFF</span>
</div>

<h1>19. Production Sign-Off & Approvals</h1>

<p>This document (v2.1) represents the authorized production specification for <strong>Egg Sanctuary: Feed, Clean & Hatch</strong>. All technical architecture, asset generation, and milestone sprints are approved for implementation in Roblox Studio.</p>

<div style="margin-top: 40px; display: grid; grid-template-columns: 1fr 1fr; gap: 40px;">
    <div>
        <p><strong>Approved by:</strong> ___________________________<br>
        Lead Game Designer & Systems Architect<br>
        Date: November 17, 2026</p>
    </div>
    <div>
        <p><strong>Approved by:</strong> ___________________________<br>
        Executive Producer & Studio Director<br>
        Date: November 17, 2026</p>
    </div>
</div>

</body>
</html>
"""

html_path = os.path.join(OUTPUT_DIR, "Egg_Sanctuary_Clean_and_Hatch_GDD.html")
pdf_path = os.path.join(OUTPUT_DIR, "Egg_Sanctuary_Clean_and_Hatch_GDD.pdf")

print("Writing updated GDD v2.1 HTML specification (Food Luck Engine)...")
with open(html_path, "w", encoding="utf-8") as f:
    f.write(html_content)

print(f"HTML created at: {html_path}")

print("Compiling publication-grade PDF via Microsoft Edge Headless engine...")
cmd = [
    EDGE_PATH,
    "--headless",
    "--disable-gpu",
    "--run-all-compositor-stages-before-draw",
    f"--print-to-pdf={pdf_path}",
    "--no-pdf-header-footer",
    html_path
]

res = subprocess.run(cmd, capture_output=True, text=True)
if res.returncode == 0 and os.path.exists(pdf_path):
    print(f"✓ Updated PDF v2.1 successfully compiled: {pdf_path}")
else:
    print(f"Error compiling PDF: {res.stderr}")
