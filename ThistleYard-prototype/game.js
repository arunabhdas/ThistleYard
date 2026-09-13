(() => {
  "use strict";

  const canvas = document.getElementById("game");
  const ctx = canvas.getContext("2d", { alpha: false });
  const heartsEl = document.getElementById("hearts");
  const coinsEl = document.getElementById("coins");
  const cluesEl = document.getElementById("clues");
  const briefEl = document.getElementById("brief");
  const restartEl = document.getElementById("restart");

  const VIEW_W = 1280;
  const VIEW_H = 720;
  const WORLD_W = 4200;
  const GRAVITY = 1750;
  const keys = new Set();
  const rand = mulberry32(27);

  const state = {
    camera: 0,
    time: 0,
    last: performance.now(),
    won: false,
    over: false,
    mouse: { x: 0, y: 0, down: false, sx: 0, sy: 0 },
    player: null,
    projectiles: [],
    particles: [],
    pickups: [],
    barrels: [],
    villagers: [],
    enemies: [],
  };

  const platforms = [
    rect(0, 660, 900, 80), rect(980, 610, 340, 42), rect(1420, 560, 460, 46),
    rect(1970, 615, 500, 56), rect(2580, 568, 330, 44), rect(3000, 510, 430, 46),
    rect(3500, 650, 700, 80), rect(180, 500, 280, 28), rect(560, 402, 260, 28),
    rect(1050, 430, 250, 28), rect(1525, 370, 260, 28), rect(2080, 440, 230, 28),
    rect(2640, 385, 240, 28), rect(3145, 310, 250, 28), rect(3640, 460, 260, 28),
    rect(350, 330, 220, 26), rect(710, 270, 220, 26), rect(1080, 220, 230, 26),
    rect(1450, 185, 230, 26), rect(1820, 230, 240, 26), rect(2190, 178, 230, 26),
    rect(2545, 145, 240, 26), rect(2905, 205, 230, 26), rect(3265, 155, 240, 26),
    rect(3625, 112, 250, 26),
  ];
  const ladders = [
    rect(650, 402, 48, 258), rect(1138, 430, 48, 180), rect(1628, 370, 48, 190),
    rect(2170, 440, 48, 175), rect(2725, 385, 48, 183), rect(3228, 310, 48, 200),
  ];
  const slopes = [
    { x1: 1320, y1: 610, x2: 1420, y2: 560 },
    { x1: 1880, y1: 560, x2: 1970, y2: 615 },
    { x1: 2470, y1: 615, x2: 2580, y2: 568 },
    { x1: 3430, y1: 510, x2: 3500, y2: 650 },
  ];

  function reset() {
    state.camera = 0;
    state.time = 0;
    state.won = false;
    state.over = false;
    state.projectiles.length = 0;
    state.particles.length = 0;
    state.pickups = [];
    state.barrels = [];
    state.enemies = [];
    state.villagers = [];
    state.player = {
      x: 80, y: 500, w: 42, h: 58, vx: 0, vy: 0, hp: 3, coins: 0, clues: 0,
      grounded: false, climbing: false, facing: 1, inv: 0, attack: 0, coyote: 0, jumpBuffer: 0, kTaps: 0,
    };
    for (let i = 0; i < 54; i++) {
      const p = platforms[(i * 3 + 2) % platforms.length];
      state.pickups.push({ type: i % 9 === 0 ? "clue" : "coin", x: p.x + 45 + rand() * (p.w - 90), y: p.y - 42, r: 12, got: false, bob: rand() * 10 });
    }
    state.villagers.push({ x: 410, y: 628, text: "Find four clues for the Yard.", seen: false });
    state.villagers.push({ x: 2290, y: 583, text: "The tower rolls barrels after dusk.", seen: false });
    state.villagers.push({ x: 3740, y: 618, text: "Strike the bell guardian twice.", seen: false });
    state.enemies.push({ x: 1160, y: 390, w: 45, h: 42, hp: 1, vx: 90, min: 1040, max: 1290 });
    state.enemies.push({ x: 2190, y: 400, w: 45, h: 42, hp: 1, vx: 105, min: 2070, max: 2320 });
    state.enemies.push({ x: 3280, y: 270, w: 52, h: 48, hp: 2, vx: 115, min: 3130, max: 3380 });
    state.enemies.push({ x: 3900, y: 596, w: 92, h: 72, hp: 4, vx: 85, min: 3660, max: 4100, boss: true });
    for (let i = 0; i < 4; i++) spawnBarrel(1250 + i * 780, 50 + i * 0.8);
    restartEl.style.display = "none";
  }

  function rect(x, y, w, h) {
    return { x, y, w, h };
  }

  function spawnBarrel(x, phase) {
    state.barrels.push({ x, y: 80, r: 18, vx: -95 - rand() * 45, vy: 0, phase, live: true });
  }

  function loop(now) {
    const dt = Math.min(0.033, (now - state.last) / 1000);
    state.last = now;
    update(dt);
    draw();
    requestAnimationFrame(loop);
  }

  function update(dt) {
    state.time += dt;
    const p = state.player;
    if (!state.over && !state.won) updatePlayer(p, dt);
    updateBarrels(dt);
    updateEnemies(dt);
    updateProjectiles(dt);
    updateParticles(dt);
    updatePickups(p);
    state.camera = clamp(p.x - VIEW_W * 0.42, 0, WORLD_W - VIEW_W);
    if (state.time > 10) briefEl.classList.add("is-quiet");
    if (p.hp <= 0 || p.y > VIEW_H + 160) end(false);
    const boss = state.enemies.find((e) => e.boss);
    if (!boss && p.clues >= 4 && p.x > 3840) end(true);
    heartsEl.textContent = "♥".repeat(Math.max(0, p.hp)) + "♡".repeat(Math.max(0, 3 - p.hp));
    coinsEl.textContent = String(p.coins);
    cluesEl.textContent = `${Math.min(4, p.clues)}/4`;
  }

  function updatePlayer(p, dt) {
    const left = keys.has("ArrowLeft") || keys.has("a");
    const right = keys.has("ArrowRight") || keys.has("d");
    const up = keys.has("ArrowUp") || keys.has("w") || keys.has(" ");
    const climbUp = keys.has("ArrowUp") || keys.has("w") || keys.has("k") || keys.has("K");
    const down = keys.has("ArrowDown") || keys.has("s");
    const onLadder = ladders.some((l) => intersects(p, ladderZone(l)));
    const jumpPressed = keys.has(" ") || (!onLadder && (keys.has("ArrowUp") || keys.has("w")));
    const wasGrounded = p.grounded;
    if (jumpPressed && !p.wasJump) p.jumpBuffer = 0.18;
    p.jumpBuffer = Math.max(0, p.jumpBuffer - dt);
    p.coyote = wasGrounded ? 0.16 : Math.max(0, p.coyote - dt);
    if (onLadder && (climbUp || down)) {
      p.climbing = true;
      p.vy = (down ? 300 : 0) - (climbUp ? 300 : 0);
      p.y += p.vy * dt;
    } else {
      p.climbing = false;
      p.vy += GRAVITY * dt;
    }
    const target = (right ? 1 : 0) - (left ? 1 : 0);
    p.vx += (target * 410 - p.vx) * Math.min(1, 13 * dt);
    if (target) p.facing = target;
    if (p.jumpBuffer > 0 && (p.grounded || p.coyote > 0 || p.climbing)) {
      p.vy = -930;
      p.grounded = false;
      p.climbing = false;
      p.coyote = 0;
      p.jumpBuffer = 0;
      puff(p.x + p.w / 2, p.y + p.h, "#f4ecd1", 8);
    }
    p.wasJump = jumpPressed;
    if ((keys.has("j") || keys.has("J")) && p.attack <= 0) p.attack = 0.18;
    p.attack = Math.max(0, p.attack - dt);
    p.inv = Math.max(0, p.inv - dt);
    moveAxis(p, "x", p.vx * dt);
    if (!p.climbing) {
      p.grounded = false;
      moveAxis(p, "y", p.vy * dt);
    }
    handleSlopes(p);
    p.x = clamp(p.x, 0, WORLD_W - p.w);
  }

  function moveAxis(body, axis, amount) {
    body[axis] += amount;
    body.grounded = axis === "y" && amount < 0 ? body.grounded : body.grounded;
    for (const plat of platforms) {
      if (!intersects(body, plat)) continue;
      if (axis === "x") {
        if (body.y + body.h <= plat.y + 30 && body.vy >= -80) continue;
        body.x = amount > 0 ? plat.x - body.w : plat.x + plat.w;
        body.vx = 0;
      } else if (amount > 0) {
        body.y = plat.y - body.h;
        body.vy = 0;
        body.grounded = true;
      } else {
        body.y = plat.y + plat.h;
        body.vy = 30;
      }
    }
    if (axis === "y" && amount > 0) body.grounded = platforms.some((plat) => body.y + body.h === plat.y && body.x + body.w > plat.x && body.x < plat.x + plat.w);
  }

  function ladderZone(ladder) {
    return { x: ladder.x - 30, y: ladder.y - 18, w: ladder.w + 60, h: ladder.h + 38 };
  }

  function klymbLadder() {
    const p = state.player;
    if (state.over || state.won) return;
    const ladder = ladders.find((l) => intersects(p, ladderZone(l)));
    if (!ladder) {
      p.kTaps = 0;
      return;
    }
    p.kTaps += 1;
    p.climbing = true;
    p.vx = 0;
    p.vy = -360;
    p.x = ladder.x + ladder.w / 2 - p.w / 2;
    if (p.kTaps < 3) {
      p.y = Math.max(ladder.y - 4, p.y - 76);
      return;
    }
    p.kTaps = 0;
    const ladderCenter = ladder.x + ladder.w / 2;
    const platform = platforms
      .filter((plat) => plat.y <= ladder.y + 12 && plat.x - 34 <= ladderCenter && plat.x + plat.w + 34 >= ladderCenter)
      .sort((a, b) => b.y - a.y)[0];
    if (!platform) return;
    p.x = clamp(ladderCenter - p.w / 2, platform.x + 8, platform.x + platform.w - p.w - 8);
    p.y = platform.y - p.h;
    p.vx = 0;
    p.vy = 0;
    p.grounded = true;
    p.climbing = false;
    puff(p.x + p.w / 2, p.y + p.h, "#f4ecd1", 10);
  }

  function handleSlopes(p) {
    for (const s of slopes) {
      if (p.x + p.w < Math.min(s.x1, s.x2) || p.x > Math.max(s.x1, s.x2)) continue;
      const t = (p.x + p.w / 2 - s.x1) / (s.x2 - s.x1);
      const y = s.y1 + (s.y2 - s.y1) * t;
      if (p.y + p.h > y - 8 && p.y + p.h < y + 42 && p.vy >= 0) {
        p.y = y - p.h;
        p.vy = 0;
        p.grounded = true;
      }
    }
  }

  function updateBarrels(dt) {
    for (const b of state.barrels) {
      if (!b.live) continue;
      b.phase += dt;
      b.vy += GRAVITY * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      const body = { x: b.x - b.r, y: b.y - b.r, w: b.r * 2, h: b.r * 2 };
      for (const plat of platforms) {
        if (intersects(body, plat) && b.vy > 0) {
          b.y = plat.y - b.r;
          b.vy = -260;
          b.vx *= 0.985;
        }
      }
      for (const s of slopes) {
        const min = Math.min(s.x1, s.x2), max = Math.max(s.x1, s.x2);
        if (b.x > min && b.x < max) {
          const t = (b.x - s.x1) / (s.x2 - s.x1);
          const y = s.y1 + (s.y2 - s.y1) * t;
          if (b.y + b.r > y - 6 && b.y < y + 38) {
            b.y = y - b.r;
            b.vy = -70;
            b.vx += (s.y2 > s.y1 ? 110 : -110) * dt;
          }
        }
      }
      if (b.x < -60 || b.y > 900) {
        b.x = 1400 + rand() * 2600;
        b.y = 40;
        b.vx = -95 - rand() * 50;
        b.vy = 0;
      }
      if (!state.player.inv && circleRect(b, state.player)) hurt();
    }
  }

  function updateEnemies(dt) {
    const p = state.player;
    for (const e of state.enemies) {
      e.x += e.vx * dt;
      if (e.x < e.min || e.x + e.w > e.max) e.vx *= -1;
      if (!p.inv && intersects(p, e)) {
        if (p.vy > 160 && p.y + p.h < e.y + e.h * 0.45) {
          e.hp -= 1;
          p.vy = -520;
          puff(e.x + e.w / 2, e.y, "#d8a441", 18);
        } else if (p.attack > 0 && Math.sign(e.x - p.x) === p.facing) {
          e.hp -= 1;
          puff(e.x + e.w / 2, e.y + 20, "#d94f38", 16);
        } else {
          hurt();
        }
      }
    }
    state.enemies = state.enemies.filter((e) => {
      if (e.hp > 0) return true;
      if (e.boss) {
        for (let i = 0; i < 14; i++) state.pickups.push({ type: i % 3 ? "coin" : "clue", x: e.x + rand() * e.w, y: e.y - rand() * 45, r: 12, got: false, bob: rand() * 4 });
      }
      return false;
    });
  }

  function updateProjectiles(dt) {
    for (const shot of state.projectiles) {
      shot.vy += GRAVITY * 0.58 * dt;
      shot.x += shot.vx * dt;
      shot.y += shot.vy * dt;
      shot.life -= dt;
      for (const e of state.enemies) {
        if (e.hp > 0 && circleRect(shot, e)) {
          e.hp -= 1;
          shot.life = 0;
          puff(shot.x, shot.y, "#f4ecd1", 20);
        }
      }
      for (const b of state.barrels) {
        if (b.live && Math.hypot(b.x - shot.x, b.y - shot.y) < b.r + shot.r) {
          b.y = 900;
          shot.life = 0;
          puff(shot.x, shot.y, "#d8a441", 16);
        }
      }
    }
    state.projectiles = state.projectiles.filter((s) => s.life > 0 && s.y < 900);
  }

  function updatePickups(p) {
    for (const item of state.pickups) {
      if (item.got) continue;
      const bob = Math.sin(state.time * 3 + item.bob) * 5;
      if (intersects(p, { x: item.x - item.r, y: item.y + bob - item.r, w: item.r * 2, h: item.r * 2 })) {
        item.got = true;
        if (item.type === "clue") p.clues += 1;
        else p.coins += 1;
        puff(item.x, item.y, item.type === "clue" ? "#314f68" : "#d8a441", 8);
      }
    }
    for (const v of state.villagers) {
      if (Math.abs(p.x - v.x) < 80 && Math.abs(p.y - v.y) < 90) v.seen = true;
    }
  }

  function updateParticles(dt) {
    for (const pt of state.particles) {
      pt.x += pt.vx * dt;
      pt.y += pt.vy * dt;
      pt.vy += 500 * dt;
      pt.life -= dt;
    }
    state.particles = state.particles.filter((pt) => pt.life > 0);
  }

  function hurt() {
    const p = state.player;
    p.hp -= 1;
    p.inv = 1.1;
    p.vx = -p.facing * 420;
    p.vy = -430;
    puff(p.x + p.w / 2, p.y + p.h / 2, "#d94f38", 22);
  }

  function end(won) {
    state.won = won;
    state.over = !won;
    restartEl.style.display = "block";
  }

  function draw() {
    ctx.clearRect(0, 0, VIEW_W, VIEW_H);
    drawSky();
    ctx.save();
    ctx.translate(-Math.round(state.camera), 0);
    drawWorld();
    drawPickups();
    drawVillagers();
    drawBarrels();
    drawEnemies();
    drawProjectiles();
    drawPlayer();
    drawParticles();
    ctx.restore();
    drawOverlay();
  }

  function drawSky() {
    const g = ctx.createLinearGradient(0, 0, 0, VIEW_H);
    g.addColorStop(0, "#9fc0b7");
    g.addColorStop(0.42, "#d8c9a4");
    g.addColorStop(1, "#3d533f");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);
    ctx.fillStyle = "rgba(244,236,209,.34)";
    for (let i = 0; i < 16; i++) {
      const x = ((i * 290 - state.camera * 0.16) % 1600) - 160;
      cloud(x, 78 + (i % 4) * 34, 42 + (i % 3) * 18);
    }
    drawHills(0.18, "#5c785d", 390, 0.7);
    drawHills(0.34, "#385c57", 500, 0.95);
    ctx.fillStyle = "rgba(23,34,30,.1)";
    for (let x = -120; x < VIEW_W + 220; x += 55) {
      const px = x - (state.camera * 0.55) % 55;
      ctx.fillRect(px, 520 + Math.sin(px * 0.03) * 8, 8, 170);
    }
  }

  function drawHills(speed, color, base, scale) {
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(0, VIEW_H);
    for (let x = -20; x <= VIEW_W + 20; x += 32) {
      const wx = x + state.camera * speed;
      const y = base + Math.sin(wx * 0.005) * 42 * scale + Math.sin(wx * 0.014) * 18;
      ctx.lineTo(x, y);
    }
    ctx.lineTo(VIEW_W, VIEW_H);
    ctx.closePath();
    ctx.fill();
  }

  function drawWorld() {
    for (let x = 120; x < WORLD_W; x += 380) {
      drawTree(x, 615 + Math.sin(x) * 30, 0.8 + (x % 5) * 0.07);
    }
    for (const s of slopes) drawSlope(s);
    for (const p of platforms) drawPlatform(p);
    for (const l of ladders) drawLadder(l);
    drawSignpost(3880, 646);
  }

  function drawPlatform(p) {
    ctx.fillStyle = "#6d5b42";
    roundRect(p.x, p.y, p.w, p.h, 7);
    ctx.fill();
    ctx.fillStyle = "#476d42";
    roundRect(p.x, p.y - 12, p.w, 18, 7);
    ctx.fill();
    ctx.fillStyle = "rgba(244,236,209,.18)";
    for (let x = p.x + 16; x < p.x + p.w - 8; x += 38) ctx.fillRect(x, p.y + 10, 20, 3);
  }

  function drawSlope(s) {
    ctx.fillStyle = "#6d5b42";
    ctx.beginPath();
    ctx.moveTo(s.x1, s.y1);
    ctx.lineTo(s.x2, s.y2);
    ctx.lineTo(s.x2, s.y2 + 58);
    ctx.lineTo(s.x1, s.y1 + 58);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = "#476d42";
    ctx.lineWidth = 14;
    ctx.beginPath();
    ctx.moveTo(s.x1, s.y1);
    ctx.lineTo(s.x2, s.y2);
    ctx.stroke();
  }

  function drawLadder(l) {
    ctx.strokeStyle = "#7d5736";
    ctx.lineWidth = 8;
    ctx.beginPath();
    ctx.moveTo(l.x + 8, l.y);
    ctx.lineTo(l.x + 8, l.y + l.h);
    ctx.moveTo(l.x + l.w - 8, l.y);
    ctx.lineTo(l.x + l.w - 8, l.y + l.h);
    ctx.stroke();
    ctx.lineWidth = 5;
    for (let y = l.y + 18; y < l.y + l.h; y += 28) {
      ctx.beginPath();
      ctx.moveTo(l.x + 4, y);
      ctx.lineTo(l.x + l.w - 4, y);
      ctx.stroke();
    }
  }

  function drawPickups() {
    for (const item of state.pickups) {
      if (item.got) continue;
      const y = item.y + Math.sin(state.time * 3 + item.bob) * 5;
      ctx.save();
      ctx.translate(item.x, y);
      ctx.rotate(state.time * 1.4);
      ctx.fillStyle = item.type === "clue" ? "#314f68" : "#d8a441";
      ctx.strokeStyle = "#f4ecd1";
      ctx.lineWidth = 3;
      if (item.type === "clue") {
        ctx.fillRect(-10, -10, 20, 20);
        ctx.strokeRect(-10, -10, 20, 20);
      } else {
        ctx.beginPath();
        ctx.arc(0, 0, 12, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
      }
      ctx.restore();
    }
  }

  function drawVillagers() {
    for (const v of state.villagers) {
      drawPerson(v.x, v.y, "#314f68", "#d8a441", 0);
      if (v.seen) {
        ctx.fillStyle = "rgba(244,236,209,.9)";
        roundRect(v.x - 105, v.y - 112, 210, 52, 8);
        ctx.fill();
        ctx.fillStyle = "#17221e";
        ctx.font = "15px Georgia";
        wrapText(v.text, v.x - 92, v.y - 90, 184, 18);
      }
    }
  }

  function drawEnemies() {
    for (const e of state.enemies) {
      ctx.save();
      ctx.translate(e.x + e.w / 2, e.y + e.h / 2);
      ctx.scale(e.vx < 0 ? -1 : 1, 1);
      ctx.fillStyle = e.boss ? "#5e2f2f" : "#314f68";
      roundRect(-e.w / 2, -e.h / 2, e.w, e.h, e.boss ? 18 : 12);
      ctx.fill();
      ctx.fillStyle = "#f4ecd1";
      ctx.beginPath();
      ctx.arc(10, -8, 5, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#d8a441";
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(-8, -e.h / 2);
      ctx.lineTo(-20, -e.h / 2 - 16);
      ctx.moveTo(8, -e.h / 2);
      ctx.lineTo(20, -e.h / 2 - 14);
      ctx.stroke();
      ctx.restore();
    }
  }

  function drawBarrels() {
    for (const b of state.barrels) {
      ctx.save();
      ctx.translate(b.x, b.y);
      ctx.rotate(b.phase * 7);
      ctx.fillStyle = "#7d5736";
      ctx.beginPath();
      ctx.arc(0, 0, b.r, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#d8a441";
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.arc(0, 0, b.r - 5, 0, Math.PI * 2);
      ctx.stroke();
      ctx.strokeStyle = "rgba(244,236,209,.45)";
      ctx.beginPath();
      ctx.moveTo(-b.r, 0);
      ctx.lineTo(b.r, 0);
      ctx.stroke();
      ctx.restore();
    }
  }

  function drawProjectiles() {
    ctx.fillStyle = "#f4ecd1";
    ctx.strokeStyle = "#17221e";
    ctx.lineWidth = 2;
    for (const s of state.projectiles) {
      ctx.beginPath();
      ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
    }
  }

  function drawPlayer() {
    const p = state.player;
    if (p.inv > 0 && Math.floor(state.time * 18) % 2) return;
    const bob = p.grounded ? Math.sin(state.time * 12) * Math.min(3, Math.abs(p.vx) / 100) : 0;
    drawPerson(p.x + p.w / 2, p.y + p.h + bob, "#d94f38", "#f4ecd1", p.facing);
    if (p.attack > 0) {
      ctx.strokeStyle = "#f4ecd1";
      ctx.lineWidth = 5;
      ctx.beginPath();
      ctx.arc(p.x + p.w / 2 + p.facing * 26, p.y + 28, 34, -0.7, 0.8);
      ctx.stroke();
    }
    if (state.mouse.down) {
      const sx = p.x + p.w / 2;
      const sy = p.y + 26;
      const mx = state.mouse.x + state.camera;
      const my = state.mouse.y;
      ctx.strokeStyle = "rgba(23,34,30,.75)";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(sx, sy);
      ctx.lineTo(mx, my);
      ctx.stroke();
      ctx.setLineDash([7, 10]);
      ctx.strokeStyle = "rgba(244,236,209,.68)";
      ctx.beginPath();
      let vx = clamp((sx - mx) * 5.5, -900, 900);
      let vy = clamp((sy - my) * 5.5, -900, 900);
      for (let t = 0; t < 1.35; t += 0.08) {
        const x = sx + vx * t;
        const y = sy + vy * t + GRAVITY * 0.29 * t * t;
        if (t === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.stroke();
      ctx.setLineDash([]);
    }
  }

  function drawPerson(x, footY, coat, face, facing) {
    ctx.save();
    ctx.translate(x, footY);
    ctx.scale(facing < 0 ? -1 : 1, 1);
    ctx.strokeStyle = "#17221e";
    ctx.lineWidth = 3;
    ctx.fillStyle = "#24362f";
    ctx.fillRect(-14, -8, 10, 8);
    ctx.fillRect(5, -8, 10, 8);
    ctx.fillStyle = coat;
    roundRect(-18, -46, 36, 38, 12);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = face;
    ctx.beginPath();
    ctx.arc(0, -58, 16, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = "#17221e";
    ctx.beginPath();
    ctx.arc(6, -60, 2.6, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#314f68";
    ctx.beginPath();
    ctx.moveTo(-20, -70);
    ctx.quadraticCurveTo(0, -88, 23, -70);
    ctx.closePath();
    ctx.fill();
    ctx.fillRect(-18, -72, 38, 6);
    ctx.restore();
  }

  function drawTree(x, y, s) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(s, s);
    ctx.fillStyle = "#6d5b42";
    ctx.fillRect(-10, -100, 20, 105);
    ctx.fillStyle = "#385c57";
    for (let i = 0; i < 4; i++) {
      ctx.beginPath();
      ctx.arc((i - 1.5) * 18, -110 - i * 16, 44 - i * 2, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  function drawSignpost(x, y) {
    ctx.fillStyle = "#7d5736";
    ctx.fillRect(x, y - 80, 12, 80);
    ctx.fillStyle = "#f4ecd1";
    roundRect(x - 72, y - 96, 154, 38, 8);
    ctx.fill();
    ctx.fillStyle = "#17221e";
    ctx.font = "18px Georgia";
    ctx.fillText("Bell Gate", x - 44, y - 71);
  }

  function drawParticles() {
    for (const pt of state.particles) {
      ctx.globalAlpha = Math.max(0, pt.life * 2);
      ctx.fillStyle = pt.color;
      ctx.fillRect(pt.x, pt.y, pt.size, pt.size);
    }
    ctx.globalAlpha = 1;
  }

  function drawOverlay() {
    if (!state.won && !state.over) return;
    ctx.fillStyle = "rgba(23,34,30,.58)";
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);
    ctx.fillStyle = "#f4ecd1";
    ctx.textAlign = "center";
    ctx.font = "700 64px Georgia";
    ctx.fillText(state.won ? "Case Closed" : "Case Gone Cold", VIEW_W / 2, 310);
    ctx.font = "24px Georgia";
    ctx.fillText(state.won ? "The village keeps its dawn." : "Restart and track the clues again.", VIEW_W / 2, 354);
    ctx.textAlign = "start";
  }

  function cloud(x, y, r) {
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.arc(x + r * 0.9, y + 5, r * 0.75, 0, Math.PI * 2);
    ctx.arc(x - r * 0.85, y + 10, r * 0.62, 0, Math.PI * 2);
    ctx.fill();
  }

  function puff(x, y, color, n) {
    for (let i = 0; i < n; i++) {
      state.particles.push({
        x, y, color, size: 3 + rand() * 5, life: 0.35 + rand() * 0.35,
        vx: (rand() - 0.5) * 420, vy: (rand() - 0.9) * 360,
      });
    }
  }

  function intersects(a, b) {
    return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
  }

  function circleRect(c, r) {
    const x = clamp(c.x, r.x, r.x + r.w);
    const y = clamp(c.y, r.y, r.y + r.h);
    return Math.hypot(c.x - x, c.y - y) < c.r;
  }

  function clamp(v, min, max) {
    return Math.max(min, Math.min(max, v));
  }

  function roundRect(x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function wrapText(text, x, y, maxWidth, lineHeight) {
    const words = text.split(" ");
    let line = "";
    for (const word of words) {
      const test = line ? `${line} ${word}` : word;
      if (ctx.measureText(test).width > maxWidth && line) {
        ctx.fillText(line, x, y);
        line = word;
        y += lineHeight;
      } else {
        line = test;
      }
    }
    ctx.fillText(line, x, y);
  }

  function mulberry32(seed) {
    return function random() {
      seed |= 0;
      seed = seed + 0x6D2B79F5 | 0;
      let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }

  window.addEventListener("keydown", (event) => {
    keys.add(event.key);
    if ((event.key === "k" || event.key === "K") && !event.repeat) klymbLadder();
    if (["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", " "].includes(event.key)) event.preventDefault();
  }, { passive: false });
  window.addEventListener("keyup", (event) => keys.delete(event.key));
  canvas.addEventListener("pointerdown", (event) => {
    const p = point(event);
    state.mouse.down = true;
    state.mouse.sx = p.x;
    state.mouse.sy = p.y;
    state.mouse.x = p.x;
    state.mouse.y = p.y;
    canvas.setPointerCapture(event.pointerId);
  });
  canvas.addEventListener("pointermove", (event) => {
    const p = point(event);
    state.mouse.x = p.x;
    state.mouse.y = p.y;
  });
  canvas.addEventListener("pointerup", () => {
    if (state.mouse.down && !state.won && !state.over) {
      const p = state.player;
      const sx = p.x + p.w / 2;
      const sy = p.y + 26;
      const mx = state.mouse.x + state.camera;
      const my = state.mouse.y;
      const vx = clamp((sx - mx) * 5.5, -900, 900);
      const vy = clamp((sy - my) * 5.5, -900, 900);
      if (Math.hypot(vx, vy) > 180) state.projectiles.push({ x: sx, y: sy, vx, vy, r: 9, life: 2.6 });
    }
    state.mouse.down = false;
  });
  restartEl.addEventListener("click", reset);

  function point(event) {
    const box = canvas.getBoundingClientRect();
    return {
      x: (event.clientX - box.left) / box.width * VIEW_W,
      y: (event.clientY - box.top) / box.height * VIEW_H,
    };
  }

  reset();
  requestAnimationFrame(loop);
})();
