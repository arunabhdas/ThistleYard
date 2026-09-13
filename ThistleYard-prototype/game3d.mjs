const THREE_URL = "https://unpkg.com/three@0.160.0/build/three.module.js";

let THREE;

import(THREE_URL)
  .then((module) => {
    THREE = module;
    boot();
  })
  .catch(() => {
    const notice = document.getElementById("notice");
    notice.textContent = "Three.js could not load. Check your connection and refresh.";
    notice.classList.add("is-visible");
  });

function boot() {
  const stage = document.getElementById("stage");
  const heartsEl = document.getElementById("hearts");
  const coinsEl = document.getElementById("coins");
  const cluesEl = document.getElementById("clues");
  const briefEl = document.getElementById("brief");
  const missionEl = document.getElementById("mission");
  const noticeEl = document.getElementById("notice");
  const restartEl = document.getElementById("restart");

  const keys = new Set();
  const clock = new THREE.Clock();
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0xa9c1b7);
  scene.fog = new THREE.Fog(0xa9c1b7, 28, 84);

  const renderer = new THREE.WebGLRenderer({
    antialias: true,
    powerPreference: "high-performance",
  });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  stage.appendChild(renderer.domElement);

  const camera = new THREE.PerspectiveCamera(42, 16 / 9, 0.1, 160);
  camera.position.set(8, 8, 24);

  const world = new THREE.Group();
  scene.add(world);

  const colors = {
    ink: 0x17221e,
    paper: 0xf4ecd1,
    brass: 0xd8a441,
    moss: 0x44694c,
    grass: 0x4d7a45,
    loch: 0x314f68,
    signal: 0xd94f38,
    wood: 0x71573a,
    stone: 0x7f826e,
    sky: 0xa9c1b7,
    heather: 0x72577a,
  };

  const mats = {
    grass: material(colors.grass, 0.9),
    wood: material(colors.wood, 0.85),
    paper: material(colors.paper, 0.8),
    brass: material(colors.brass, 0.62, 0.08),
    loch: material(colors.loch, 0.82),
    signal: material(colors.signal, 0.72),
    ink: material(colors.ink, 0.78),
    stone: material(colors.stone, 0.9),
    heather: material(colors.heather, 0.85),
    glass: new THREE.MeshStandardMaterial({
      color: 0xdfe7d1,
      roughness: 0.35,
      metalness: 0,
      transparent: true,
      opacity: 0.74,
    }),
  };

  function material(color, roughness = 0.8, metalness = 0) {
    return new THREE.MeshStandardMaterial({ color, roughness, metalness });
  }

  const boxGeo = new THREE.BoxGeometry(1, 1, 1);
  const coinGeo = new THREE.TorusGeometry(0.28, 0.07, 10, 22);
  const clueGeo = new THREE.BoxGeometry(0.42, 0.56, 0.08);
  const projectileGeo = new THREE.SphereGeometry(0.18, 16, 10);
  const shadowGeo = new THREE.CircleGeometry(1, 24);
  const shadowMat = new THREE.MeshBasicMaterial({
    color: 0x0b1714,
    transparent: true,
    opacity: 0.18,
    depthWrite: false,
  });

  const state = {
    time: 0,
    cameraX: 8,
    cameraY: 8,
    over: false,
    won: false,
    quietHud: false,
    coins: 0,
    clues: 0,
    player: {
      x: 3,
      y: 0,
      w: 0.95,
      h: 2.2,
      vx: 0,
      vy: 0,
      hp: 3,
      facing: 1,
      grounded: false,
      climbing: false,
      coyote: 0,
      jumpBuffer: 0,
      attack: 0,
      inv: 0,
      kTaps: 0,
    },
    aim: { down: false, sx: 0, sy: 0, x: 0, y: 0 },
    projectiles: [],
    pickups: [],
    enemies: [],
    barrels: [],
    villagers: [],
  };

  const platforms = [
    platform(8, 0, 19, 1.35),
    platform(28, 0, 13, 1.35),
    platform(48, 0, 18, 1.35),
    platform(74, 0, 22, 1.35),
    platform(105, 0, 18, 1.35),
    platform(134, 0, 26, 1.35),
    platform(23, 2.9, 9.4, 0.9),
    platform(37, 5.7, 9.2, 0.9),
    platform(52, 8.5, 10.4, 0.9),
    platform(68, 11.2, 10.8, 0.9),
    platform(85, 14, 10.6, 0.9),
    platform(102, 16.8, 10.6, 0.9),
    platform(119, 19.6, 11.4, 0.9),
    platform(137, 22.4, 15, 0.9),
    platform(17, 7.3, 7.5, 0.8),
    platform(58, 4.3, 8.5, 0.8),
    platform(92, 7.7, 8.5, 0.8),
    platform(126, 9.5, 8.5, 0.8),
  ];

  const ladders = [
    ladder(23, 0, 2.9),
    ladder(37, 2.9, 5.7),
    ladder(52, 5.7, 8.5),
    ladder(68, 8.5, 11.2),
    ladder(85, 11.2, 14),
    ladder(102, 14, 16.8),
    ladder(119, 16.8, 19.6),
    ladder(137, 19.6, 22.4),
  ];

  const startPositions = {
    barrels: [
      { x: 79, y: 14.9, vx: -3.1 },
      { x: 121, y: 20.5, vx: -2.7 },
      { x: 140, y: 23.3, vx: -2.45 },
    ],
    enemies: [
      { x: 55, y: 8.5, min: 48, max: 57, hp: 1, speed: 2.1 },
      { x: 93, y: 7.7, min: 88.5, max: 96, hp: 1, speed: 2.4 },
      { x: 121, y: 19.6, min: 114, max: 124, hp: 2, speed: 2.2 },
      { x: 142, y: 22.4, min: 132, max: 146, hp: 4, speed: 1.6, boss: true },
    ],
  };

  const playerMesh = makePlayer();
  world.add(playerMesh.group);

  const aimLine = new THREE.Line(
    new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(), new THREE.Vector3()]),
    new THREE.LineBasicMaterial({ color: colors.paper, transparent: true, opacity: 0.8 })
  );
  aimLine.visible = false;
  world.add(aimLine);

  buildLights();
  buildScenery();
  buildPlatforms();
  buildLadders();
  buildVillage();
  buildPickups();
  buildEnemies();
  buildBarrels();
  resetGame();
  resize();

  window.addEventListener("resize", resize);
  window.addEventListener("keydown", onKeyDown, { passive: false });
  window.addEventListener("keyup", (event) => keys.delete(event.key.toLowerCase()));
  renderer.domElement.addEventListener("pointerdown", onPointerDown);
  renderer.domElement.addEventListener("pointermove", onPointerMove);
  renderer.domElement.addEventListener("pointerup", onPointerUp);
  restartEl.addEventListener("click", resetGame);
  renderer.setAnimationLoop(tick);

  function platform(x, y, w, h) {
    return { x, y, w, h, depth: 4.3 };
  }

  function ladder(x, bottom, top) {
    return { x, bottom, top, w: 1.45 };
  }

  function buildLights() {
    scene.add(new THREE.HemisphereLight(0xf4ecd1, 0x28443c, 2.25));
    const sun = new THREE.DirectionalLight(0xfff3cb, 2.15);
    sun.position.set(-12, 24, 18);
    scene.add(sun);
    const rim = new THREE.DirectionalLight(0x8fb8ff, 0.75);
    rim.position.set(30, 16, -12);
    scene.add(rim);
  }

  function buildScenery() {
    world.add(makeHill(-12, -2.4, -8.5, 0x62825f, 0.42, 20));
    world.add(makeHill(-8, -4.2, -7.1, 0x375e58, 0.62, 15));

    for (let i = 0; i < 16; i += 1) {
      const cloud = makeCloud(8 + i * 10.8, 18 + (i % 5) * 1.6, -10 - (i % 3) * 3, 0.9 + (i % 4) * 0.2);
      world.add(cloud);
    }

    for (let x = -3; x < 153; x += 6.2) {
      const tree = makeTree(x, -0.05, -4.8 - (x % 3), 0.8 + ((x * 17) % 5) * 0.08);
      world.add(tree);
    }

    const loch = new THREE.Mesh(new THREE.BoxGeometry(165, 0.15, 8), new THREE.MeshBasicMaterial({ color: 0x2d5a5c, transparent: true, opacity: 0.4 }));
    loch.position.set(73, -1.22, -4.2);
    world.add(loch);
  }

  function makeHill(x, y, z, color, scaleY, phase) {
    const shape = new THREE.Shape();
    shape.moveTo(-18, -8);
    for (let i = 0; i <= 48; i += 1) {
      const px = -18 + i * 4;
      const py = Math.sin((px + phase) * 0.1) * 2.2 * scaleY + Math.sin((px + phase) * 0.037) * 3.4 * scaleY;
      shape.lineTo(px, py);
    }
    shape.lineTo(174, -8);
    shape.closePath();
    const mesh = new THREE.Mesh(new THREE.ShapeGeometry(shape), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.92 }));
    mesh.position.set(x, y, z);
    return mesh;
  }

  function makeCloud(x, y, z, scale) {
    const group = new THREE.Group();
    const geo = new THREE.SphereGeometry(1, 14, 8);
    const mat = new THREE.MeshBasicMaterial({ color: 0xf1ecd4, transparent: true, opacity: 0.34, depthWrite: false });
    const parts = [
      [-1.2, 0, 0.8],
      [0, 0.3, 1.15],
      [1.15, -0.05, 0.9],
      [2.1, -0.18, 0.7],
    ];
    for (const [px, py, s] of parts) {
      const puff = new THREE.Mesh(geo, mat);
      puff.position.set(px * scale, py * scale, 0);
      puff.scale.setScalar(s * scale);
      group.add(puff);
    }
    group.position.set(x, y, z);
    return group;
  }

  function makeTree(x, y, z, scale) {
    const group = new THREE.Group();
    const trunk = box(0, 0.95 * scale, 0, 0.42 * scale, 1.9 * scale, 0.42 * scale, mats.wood);
    const crown = new THREE.Mesh(new THREE.ConeGeometry(1.2 * scale, 3.1 * scale, 7), mats.moss);
    crown.position.y = 3.0 * scale;
    const crown2 = new THREE.Mesh(new THREE.ConeGeometry(0.9 * scale, 2.5 * scale, 7), mats.grass);
    crown2.position.set(0.2 * scale, 4.1 * scale, 0.05);
    group.add(trunk, crown, crown2);
    group.position.set(x, y - 1.4, z);
    return group;
  }

  function buildPlatforms() {
    for (const plat of platforms) {
      const base = box(plat.x, plat.y - plat.h / 2, 0, plat.w, plat.h, plat.depth, mats.wood);
      const cap = box(plat.x, plat.y + 0.13, 0, plat.w + 0.25, 0.26, plat.depth + 0.32, mats.grass);
      const trim = box(plat.x, plat.y - 0.18, 2.24, plat.w * 0.92, 0.08, 0.08, mats.glass);
      world.add(base, cap, trim);

      const shadow = new THREE.Mesh(shadowGeo, shadowMat);
      shadow.rotation.x = -Math.PI / 2;
      shadow.position.set(plat.x, plat.y - plat.h - 0.02, 0);
      shadow.scale.set(plat.w * 0.42, plat.depth * 0.42, 1);
      world.add(shadow);
    }
  }

  function buildLadders() {
    for (const l of ladders) {
      const height = l.top - l.bottom;
      const y = l.bottom + height / 2;
      world.add(box(l.x - 0.42, y, 2.45, 0.16, height, 0.16, mats.wood));
      world.add(box(l.x + 0.42, y, 2.45, 0.16, height, 0.16, mats.wood));
      for (let rungY = l.bottom + 0.45; rungY < l.top - 0.1; rungY += 0.65) {
        world.add(box(l.x, rungY, 2.45, 1.05, 0.12, 0.16, mats.wood));
      }
    }
  }

  function buildVillage() {
    for (const spec of [
      { x: 11, y: 0, z: -2.6, s: 0.85 },
      { x: 62, y: 0, z: -2.8, s: 0.75 },
      { x: 112, y: 0, z: -2.8, s: 0.9 },
    ]) {
      const house = new THREE.Group();
      house.add(box(0, 0.8 * spec.s, 0, 2.3 * spec.s, 1.6 * spec.s, 1.5 * spec.s, mats.paper));
      const roof = new THREE.Mesh(new THREE.ConeGeometry(1.65 * spec.s, 1.1 * spec.s, 4), mats.signal);
      roof.rotation.y = Math.PI / 4;
      roof.position.y = 1.95 * spec.s;
      house.add(roof);
      house.add(box(-0.55 * spec.s, 0.8 * spec.s, 0.78 * spec.s, 0.32 * spec.s, 0.5 * spec.s, 0.06 * spec.s, mats.loch));
      house.add(box(0.55 * spec.s, 0.8 * spec.s, 0.78 * spec.s, 0.32 * spec.s, 0.5 * spec.s, 0.06 * spec.s, mats.loch));
      house.position.set(spec.x, spec.y, spec.z);
      world.add(house);
    }

    state.villagers = [
      makeVillager(16, 0, "Find four clues for the Yard."),
      makeVillager(70, 11.2, "Three K taps will klymb any ladder."),
      makeVillager(130, 0, "The bell gate opens past the boss."),
    ];
  }

  function makeVillager(x, y, text) {
    const group = new THREE.Group();
    const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.34, 0.8, 4, 8), mats.loch);
    body.position.y = 0.72;
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.32, 16, 10), mats.brass);
    head.position.y = 1.54;
    const hat = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.42, 0.16, 18), mats.ink);
    hat.position.y = 1.92;
    group.add(body, head, hat);
    group.position.set(x, y, 1.2);
    world.add(group);
    return { x, y, text, group, seen: false };
  }

  function buildPickups() {
    const placement = [
      [23, 3.7, "coin"], [26, 3.7, "coin"], [37, 6.5, "clue"], [41, 6.5, "coin"],
      [52, 9.3, "coin"], [56, 9.3, "coin"], [68, 12, "clue"], [72, 12, "coin"],
      [85, 14.8, "coin"], [89, 14.8, "coin"], [102, 17.6, "clue"], [106, 17.6, "coin"],
      [119, 20.4, "coin"], [123, 20.4, "coin"], [137, 23.2, "clue"], [143, 23.2, "coin"],
      [58, 5.1, "coin"], [92, 8.5, "coin"], [126, 10.3, "coin"],
    ];
    for (const [x, y, type] of placement) {
      const mesh = type === "coin" ? new THREE.Mesh(coinGeo, mats.brass) : new THREE.Mesh(clueGeo, mats.loch);
      mesh.position.set(x, y, 1.1);
      mesh.rotation.y = Math.PI / 2;
      world.add(mesh);
      state.pickups.push({ x, y, type, mesh, got: false, bob: x * 0.31 });
    }
  }

  function buildEnemies() {
    for (const spec of startPositions.enemies) {
      const group = new THREE.Group();
      const body = new THREE.Mesh(new THREE.CapsuleGeometry(spec.boss ? 0.72 : 0.45, spec.boss ? 1.15 : 0.8, 5, 12), spec.boss ? mats.signal : mats.loch);
      body.position.y = spec.boss ? 1.05 : 0.72;
      const hat = new THREE.Mesh(new THREE.ConeGeometry(spec.boss ? 0.75 : 0.45, spec.boss ? 0.8 : 0.42, 5), mats.ink);
      hat.position.y = spec.boss ? 2.1 : 1.55;
      group.add(body, hat);
      world.add(group);
      state.enemies.push({
        ...spec,
        mesh: group,
        w: spec.boss ? 1.7 : 1.05,
        h: spec.boss ? 2.2 : 1.65,
        vx: spec.speed,
        initialHp: spec.hp,
        dead: false,
      });
    }
  }

  function buildBarrels() {
    for (const spec of startPositions.barrels) {
      const group = new THREE.Group();
      const shell = new THREE.Mesh(new THREE.SphereGeometry(0.5, 18, 12), mats.wood);
      const band1 = new THREE.Mesh(new THREE.TorusGeometry(0.51, 0.035, 8, 20), mats.brass);
      const band2 = band1.clone();
      band1.rotation.y = Math.PI / 2;
      band2.rotation.y = Math.PI / 2;
      band1.position.x = -0.24;
      band2.position.x = 0.24;
      group.add(shell, band1, band2);
      world.add(group);
      state.barrels.push({ ...spec, spawnX: spec.x, spawnY: spec.y, spawnVx: spec.vx, y: spec.y, vy: 0, r: 0.5, mesh: group });
    }
  }

  function makePlayer() {
    const group = new THREE.Group();
    const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.46, 1.02, 6, 16), mats.signal);
    body.position.y = 1.0;
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.42, 18, 12), mats.paper);
    head.position.y = 2.05;
    const hat = new THREE.Mesh(new THREE.CylinderGeometry(0.54, 0.48, 0.18, 20), mats.loch);
    hat.position.y = 2.43;
    const brim = new THREE.Mesh(new THREE.BoxGeometry(0.98, 0.08, 0.32), mats.loch);
    brim.position.set(0.16, 2.34, 0.22);
    const eye = new THREE.Mesh(new THREE.SphereGeometry(0.05, 8, 6), mats.ink);
    eye.position.set(0.18, 2.11, 0.39);
    const cane = box(0.6, 0.85, 0.18, 0.08, 1.24, 0.08, mats.brass);
    cane.rotation.z = -0.24;
    group.add(body, head, hat, brim, eye, cane);

    const shadow = new THREE.Mesh(shadowGeo, shadowMat);
    shadow.rotation.x = -Math.PI / 2;
    shadow.scale.set(0.72, 0.34, 1);
    world.add(shadow);
    return { group, shadow };
  }

  function box(x, y, z, w, h, d, mat) {
    const mesh = new THREE.Mesh(boxGeo, mat);
    mesh.position.set(x, y, z);
    mesh.scale.set(w, h, d);
    return mesh;
  }

  function resetGame() {
    Object.assign(state.player, {
      x: 3,
      y: 0,
      vx: 0,
      vy: 0,
      hp: 3,
      facing: 1,
      grounded: false,
      climbing: false,
      coyote: 0,
      jumpBuffer: 0,
      attack: 0,
      inv: 0,
      kTaps: 0,
    });
    state.time = 0;
    state.over = false;
    state.won = false;
    state.coins = 0;
    state.clues = 0;
    state.quietHud = false;
    briefEl.classList.remove("is-quiet");
    for (const shot of state.projectiles) world.remove(shot.mesh);
    state.projectiles = [];
    for (const item of state.pickups) {
      item.got = false;
      item.mesh.visible = true;
    }
    for (const enemy of state.enemies) {
      const start = startPositions.enemies[state.enemies.indexOf(enemy)];
      enemy.hp = enemy.initialHp;
      enemy.dead = false;
      enemy.mesh.visible = true;
      enemy.x = start.x;
      enemy.vx = enemy.speed;
    }
    for (const barrel of state.barrels) {
      barrel.x = barrel.spawnX;
      barrel.y = barrel.spawnY;
      barrel.vx = barrel.spawnVx;
      barrel.vy = 0;
    }
    for (const villager of state.villagers) villager.seen = false;
    noticeEl.classList.remove("is-visible");
    restartEl.style.display = "none";
    missionEl.textContent = "Collect four clues, outwit the Yard, and reach the bell gate.";
    syncHud();
  }

  function tick() {
    const dt = Math.min(clock.getDelta(), 0.033);
    state.time += dt;
    if (!state.over && !state.won) {
      updatePlayer(dt);
      updateEnemies(dt);
      updateBarrels(dt);
      updateProjectiles(dt);
      updatePickups();
      updateVillagers();
      checkWinLoss();
    }
    updateVisuals(dt);
    renderer.render(scene, camera);
  }

  function updatePlayer(dt) {
    const p = state.player;
    const left = keys.has("arrowleft") || keys.has("a");
    const right = keys.has("arrowright") || keys.has("d");
    const climbUp = keys.has("arrowup") || keys.has("w") || keys.has("k");
    const down = keys.has("arrowdown") || keys.has("s");
    const onLadder = findLadder();
    const jumpPressed = keys.has(" ") || (!onLadder && (keys.has("arrowup") || keys.has("w")));
    const wasGrounded = p.grounded;

    if (jumpPressed && !p.wasJump) p.jumpBuffer = 0.18;
    p.jumpBuffer = Math.max(0, p.jumpBuffer - dt);
    p.coyote = wasGrounded ? 0.16 : Math.max(0, p.coyote - dt);

    if (onLadder && (climbUp || down)) {
      p.climbing = true;
      p.vy = (climbUp ? 8.2 : 0) - (down ? 8.2 : 0);
      p.x += (onLadder.x - p.x) * Math.min(1, dt * 9);
      p.y = clamp(p.y + p.vy * dt, onLadder.bottom, onLadder.top);
      if (p.y >= onLadder.top - 0.02) {
        p.y = onLadder.top;
        p.vy = 0;
        p.grounded = true;
      }
    } else {
      p.climbing = false;
      p.vy -= 31 * dt;
    }

    const targetSpeed = (right ? 1 : 0) - (left ? 1 : 0);
    p.vx += (targetSpeed * 9.2 - p.vx) * Math.min(1, 15 * dt);
    if (targetSpeed) p.facing = targetSpeed;

    if (p.jumpBuffer > 0 && (p.grounded || p.coyote > 0 || p.climbing)) {
      p.vy = 15.9;
      p.grounded = false;
      p.climbing = false;
      p.coyote = 0;
      p.jumpBuffer = 0;
      puff(p.x, p.y + 0.15, colors.paper, 8);
    }

    p.wasJump = jumpPressed;
    p.attack = Math.max(0, p.attack - dt);
    p.inv = Math.max(0, p.inv - dt);

    moveHorizontally(p, p.vx * dt);
    if (!p.climbing) moveVertically(p, p.vy * dt);
    p.x = clamp(p.x, 0.4, 150);
  }

  function moveHorizontally(p, amount) {
    p.x += amount;
    for (const plat of platforms) {
      if (!rectOverlaps(p, plat)) continue;
      if (p.y >= plat.y - 0.18) continue;
      if (amount > 0) p.x = plat.x - plat.w / 2 - p.w / 2;
      else if (amount < 0) p.x = plat.x + plat.w / 2 + p.w / 2;
      p.vx = 0;
    }
  }

  function moveVertically(p, amount) {
    const oldY = p.y;
    const oldTop = p.y + p.h;
    p.y += amount;
    p.grounded = false;
    for (const plat of platforms) {
      if (!horizontalOverlap(p, plat)) continue;
      const bottom = plat.y - plat.h;
      if (amount <= 0 && oldY >= plat.y && p.y <= plat.y) {
        p.y = plat.y;
        p.vy = 0;
        p.grounded = true;
      } else if (amount > 0 && oldTop <= bottom && p.y + p.h >= bottom) {
        p.y = bottom - p.h;
        p.vy = 0;
      }
    }
  }

  function updateEnemies(dt) {
    const p = state.player;
    if (keys.has("j") && p.attack <= 0) {
      p.attack = 0.2;
      for (const enemy of state.enemies) {
        if (enemy.dead) continue;
        const inRange = Math.abs(enemy.x - p.x) < 2.8 && Math.abs(enemy.y - p.y) < 3.2 && Math.sign(enemy.x - p.x) === p.facing;
        if (inRange) damageEnemy(enemy, 1);
      }
    }

    for (const enemy of state.enemies) {
      if (enemy.dead) continue;
      enemy.x += enemy.vx * dt;
      if (enemy.x < enemy.min || enemy.x > enemy.max) enemy.vx *= -1;

      const playerHits = Math.abs(p.x - enemy.x) < (p.w + enemy.w) * 0.52 && p.y < enemy.y + enemy.h && p.y + p.h > enemy.y;
      if (!playerHits || p.inv > 0) continue;

      if (p.vy < -2 && p.y > enemy.y + enemy.h * 0.48) {
        damageEnemy(enemy, 1);
        p.vy = 11.5;
      } else if (p.attack > 0 && Math.sign(enemy.x - p.x) === p.facing) {
        damageEnemy(enemy, 1);
      } else {
        hurt();
      }
    }
  }

  function damageEnemy(enemy, amount) {
    enemy.hp -= amount;
    puff(enemy.x, enemy.y + enemy.h * 0.65, enemy.boss ? colors.signal : colors.brass, 10);
    if (enemy.hp <= 0) {
      enemy.dead = true;
      enemy.mesh.visible = false;
      if (enemy.boss) missionEl.textContent = "The bell gate is open. Carry four clues past the right edge.";
    }
  }

  function updateBarrels(dt) {
    const p = state.player;
    for (const barrel of state.barrels) {
      const oldBottom = barrel.y - barrel.r;
      barrel.vy -= 27 * dt;
      barrel.x += barrel.vx * dt;
      barrel.y += barrel.vy * dt;
      for (const plat of platforms) {
        if (barrel.x + barrel.r < plat.x - plat.w / 2 || barrel.x - barrel.r > plat.x + plat.w / 2) continue;
        const bottom = barrel.y - barrel.r;
        if (oldBottom >= plat.y && bottom <= plat.y) {
          barrel.y = plat.y + barrel.r;
          barrel.vy = 0;
          barrel.vx *= 0.998;
        }
      }
      if (barrel.y < -10 || barrel.x < state.cameraX - 48) {
        barrel.x = barrel.spawnX + 5 * Math.sin(state.time + barrel.spawnX);
        barrel.y = barrel.spawnY;
        barrel.vx = barrel.spawnVx;
        barrel.vy = 0;
      }
      if (p.inv <= 0 && Math.abs(p.x - barrel.x) < p.w / 2 + barrel.r && p.y < barrel.y + barrel.r && p.y + p.h > barrel.y - barrel.r) hurt();
    }
  }

  function updateProjectiles(dt) {
    for (const shot of state.projectiles) {
      shot.vy -= 18 * dt;
      shot.x += shot.vx * dt;
      shot.y += shot.vy * dt;
      shot.life -= dt;
      for (const enemy of state.enemies) {
        if (enemy.dead) continue;
        if (Math.abs(enemy.x - shot.x) < enemy.w * 0.7 && shot.y > enemy.y && shot.y < enemy.y + enemy.h + 0.4) {
          damageEnemy(enemy, 1);
          shot.life = 0;
          puff(shot.x, shot.y, colors.paper, 8);
        }
      }
      for (const barrel of state.barrels) {
        if (Math.hypot(barrel.x - shot.x, barrel.y - shot.y) < barrel.r + 0.3) {
          barrel.y = -12;
          shot.life = 0;
          puff(shot.x, shot.y, colors.brass, 8);
        }
      }
    }
    state.projectiles = state.projectiles.filter((shot) => {
      const alive = shot.life > 0 && shot.y > -8;
      if (!alive) world.remove(shot.mesh);
      return alive;
    });
  }

  function updatePickups() {
    const p = state.player;
    for (const item of state.pickups) {
      if (item.got) continue;
      const y = item.y + Math.sin(state.time * 3 + item.bob) * 0.18;
      if (Math.abs(p.x - item.x) < 1.0 && p.y < y + 0.7 && p.y + p.h > y - 0.7) {
        item.got = true;
        item.mesh.visible = false;
        if (item.type === "clue") state.clues += 1;
        else state.coins += 1;
        puff(item.x, y, item.type === "clue" ? colors.loch : colors.brass, 8);
      }
    }
    syncHud();
  }

  function updateVillagers() {
    const p = state.player;
    for (const villager of state.villagers) {
      if (Math.abs(p.x - villager.x) < 2.2 && Math.abs(p.y - villager.y) < 2.8) {
        villager.seen = true;
        missionEl.textContent = villager.text;
      }
    }
  }

  function checkWinLoss() {
    const boss = state.enemies.find((enemy) => enemy.boss && !enemy.dead);
    if (state.player.hp <= 0 || state.player.y < -13) finish(false);
    if (!boss && state.clues >= 4 && state.player.x > 146) finish(true);
  }

  function finish(won) {
    state.won = won;
    state.over = !won;
    noticeEl.textContent = won ? "Case Closed" : "Case Gone Cold";
    noticeEl.classList.add("is-visible");
    restartEl.style.display = "block";
  }

  function hurt() {
    const p = state.player;
    p.hp -= 1;
    p.inv = 1.1;
    p.vx = -p.facing * 6.5;
    p.vy = 8.8;
    puff(p.x, p.y + 1.1, colors.signal, 12);
    syncHud();
  }

  function klymbLadder() {
    const p = state.player;
    if (state.over || state.won) return;
    const l = findLadder(2.0);
    if (!l) {
      p.kTaps = 0;
      return;
    }
    p.kTaps += 1;
    p.climbing = true;
    p.vx = 0;
    p.vy = 0;
    p.x = l.x;
    if (p.kTaps < 3) {
      p.y = Math.min(l.top - 0.18, p.y + Math.max(0.8, (l.top - p.y) * 0.42));
      puff(p.x, p.y + 0.2, colors.paper, 4);
      return;
    }
    p.kTaps = 0;
    p.y = l.top;
    p.grounded = true;
    p.climbing = false;
    puff(p.x, p.y + 0.2, colors.paper, 12);
  }

  function findLadder(extra = 0.85) {
    const p = state.player;
    return ladders.find((l) => Math.abs(p.x - l.x) < l.w + extra && p.y < l.top + 0.7 && p.y + p.h > l.bottom - 0.8);
  }

  function updateVisuals() {
    const p = state.player;
    playerMesh.group.position.set(p.x, p.y, 0.85);
    playerMesh.group.rotation.y = p.facing > 0 ? 0 : Math.PI;
    playerMesh.group.visible = !(p.inv > 0 && Math.floor(state.time * 18) % 2 === 0);
    playerMesh.shadow.position.set(p.x, floorBelow(p.x, p.y) + 0.03, 0.82);
    playerMesh.shadow.visible = p.y > -8;
    playerMesh.group.scale.set(p.attack > 0 ? 1.08 : 1, 1, 1);

    for (const item of state.pickups) {
      if (!item.mesh.visible) continue;
      item.mesh.position.y = item.y + Math.sin(state.time * 3 + item.bob) * 0.18;
      item.mesh.rotation.y += 0.045;
    }
    for (const enemy of state.enemies) {
      enemy.mesh.position.set(enemy.x, enemy.y, 0.85);
      enemy.mesh.rotation.y = enemy.vx >= 0 ? 0 : Math.PI;
    }
    for (const barrel of state.barrels) {
      barrel.mesh.position.set(barrel.x, barrel.y, 0.85);
      barrel.mesh.rotation.z -= barrel.vx * 0.04;
    }
    for (const shot of state.projectiles) shot.mesh.position.set(shot.x, shot.y, 0.85);

    updateAimLine();
    updateCamera();
    if (!state.quietHud && state.time > 9) {
      state.quietHud = true;
      briefEl.classList.add("is-quiet");
    }
  }

  function updateCamera() {
    const p = state.player;
    const targetX = clamp(p.x + 5.4, 8, 140);
    const targetY = clamp(p.y + 7.5, 7.4, 28.5);
    state.cameraX += (targetX - state.cameraX) * 0.08;
    state.cameraY += (targetY - state.cameraY) * 0.08;
    camera.position.set(state.cameraX, state.cameraY, 24);
    camera.lookAt(p.x + 4, p.y + 2.6, 0);
  }

  function updateAimLine() {
    if (!state.aim.down) {
      aimLine.visible = false;
      return;
    }
    const p = state.player;
    const pullX = clamp((state.aim.sx - state.aim.x) * 0.018, -6, 6);
    const pullY = clamp((state.aim.y - state.aim.sy) * 0.018, -2, 6);
    const start = new THREE.Vector3(p.x, p.y + 1.45, 1.25);
    const end = new THREE.Vector3(p.x + pullX, p.y + 1.45 + pullY, 1.25);
    aimLine.geometry.setFromPoints([start, end]);
    aimLine.visible = true;
  }

  function floorBelow(x, y) {
    let best = -1.2;
    for (const plat of platforms) {
      if (x > plat.x - plat.w / 2 && x < plat.x + plat.w / 2 && plat.y <= y + 0.05) best = Math.max(best, plat.y);
    }
    return best;
  }

  function syncHud() {
    heartsEl.textContent = "♥".repeat(Math.max(0, state.player.hp)) + "♡".repeat(Math.max(0, 3 - state.player.hp));
    coinsEl.textContent = String(state.coins);
    cluesEl.textContent = `${Math.min(4, state.clues)}/4`;
  }

  function horizontalOverlap(p, plat) {
    return p.x + p.w / 2 > plat.x - plat.w / 2 && p.x - p.w / 2 < plat.x + plat.w / 2;
  }

  function rectOverlaps(p, plat) {
    const vertical = p.y < plat.y && p.y + p.h > plat.y - plat.h;
    return vertical && horizontalOverlap(p, plat);
  }

  function puff(x, y, color, count) {
    const group = new THREE.Group();
    const mat = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.88 });
    for (let i = 0; i < count; i += 1) {
      const fleck = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.08, 0.08), mat);
      fleck.position.set(x, y, 1 + (i % 3) * 0.15);
      fleck.userData = {
        vx: (Math.random() - 0.5) * 4.8,
        vy: Math.random() * 4.3,
        life: 0.45 + Math.random() * 0.3,
      };
      group.add(fleck);
    }
    world.add(group);
    const start = state.time;
    const animate = () => {
      const age = state.time - start;
      for (const fleck of group.children) {
        fleck.position.x += fleck.userData.vx * 0.016;
        fleck.position.y += fleck.userData.vy * 0.016;
        fleck.userData.vy -= 9 * 0.016;
        fleck.material.opacity = Math.max(0, 1 - age / fleck.userData.life);
      }
      if (age < 0.8) requestAnimationFrame(animate);
      else world.remove(group);
    };
    requestAnimationFrame(animate);
  }

  function onKeyDown(event) {
    const key = event.key.toLowerCase();
    keys.add(key);
    if (key === "k" && !event.repeat) klymbLadder();
    if (["arrowleft", "arrowright", "arrowup", "arrowdown", " "].includes(key)) event.preventDefault();
  }

  function onPointerDown(event) {
    const p = pointerPoint(event);
    state.aim.down = true;
    state.aim.sx = p.x;
    state.aim.sy = p.y;
    state.aim.x = p.x;
    state.aim.y = p.y;
    renderer.domElement.setPointerCapture(event.pointerId);
  }

  function onPointerMove(event) {
    const p = pointerPoint(event);
    state.aim.x = p.x;
    state.aim.y = p.y;
  }

  function onPointerUp() {
    if (state.aim.down && !state.over && !state.won) {
      const dx = state.aim.sx - state.aim.x;
      const dy = state.aim.y - state.aim.sy;
      const vx = clamp(dx * 0.055, -18, 18);
      const vy = clamp(dy * 0.06, -5, 16);
      if (Math.hypot(vx, vy) > 4.5) {
        const p = state.player;
        const mesh = new THREE.Mesh(projectileGeo, mats.paper);
        world.add(mesh);
        state.projectiles.push({
          x: p.x + p.facing * 0.45,
          y: p.y + 1.48,
          vx,
          vy,
          life: 2.6,
          mesh,
        });
      }
    }
    state.aim.down = false;
  }

  function pointerPoint(event) {
    const rect = renderer.domElement.getBoundingClientRect();
    return {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top,
    };
  }

  function resize() {
    const width = Math.max(1, stage.clientWidth);
    const height = Math.max(1, stage.clientHeight);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    renderer.setSize(width, height, false);
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }
}
