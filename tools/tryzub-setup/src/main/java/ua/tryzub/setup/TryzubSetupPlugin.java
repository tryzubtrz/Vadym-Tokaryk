package ua.tryzub.setup;

import org.bukkit.Bukkit;
import org.bukkit.GameRule;
import org.bukkit.Location;
import org.bukkit.Material;
import org.bukkit.Sound;
import org.bukkit.World;
import org.bukkit.block.Block;
import org.bukkit.block.BlockFace;
import org.bukkit.block.data.type.Bed;
import org.bukkit.command.Command;
import org.bukkit.command.CommandSender;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.entity.ArmorStand;
import org.bukkit.entity.EntityType;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.inventory.InventoryClickEvent;
import org.bukkit.event.player.PlayerInteractEvent;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.event.block.Action;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;
import org.bukkit.plugin.java.JavaPlugin;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/**
 * MineLegacy-style hub: красиве лобі, голограми, донати, арена BedWars.
 */
public final class TryzubSetupPlugin extends JavaPlugin implements Listener {

    private String mode;
    private File coinsFile;
    private FileConfiguration coins;
    private final Map<UUID, Long> clickCooldown = new HashMap<>();

    @Override
    public void onEnable() {
        saveDefaultConfig();
        mode = getConfig().getString("mode", "generic").toLowerCase(Locale.ROOT);
        coinsFile = new File(getDataFolder(), "coins.yml");
        coins = YamlConfiguration.loadConfiguration(coinsFile);
        Bukkit.getMessenger().registerOutgoingPluginChannel(this, "BungeeCord");
        Bukkit.getPluginManager().registerEvents(this, this);
        Bukkit.getScheduler().runTaskLater(this, this::bootstrap, 40L);
        getLogger().info("MineLegacy Hub увімкнено (режим: " + mode + ")");
    }

    @Override
    public void onDisable() {
        saveCoins();
    }

    private void bootstrap() {
        File marker = new File(getDataFolder(), "bootstrapped.flag");
        if (marker.exists() && !getConfig().getBoolean("force-rebuild", false)) {
            if ("lobby".equals(mode)) {
                spawnLobbyHolograms(Bukkit.getWorlds().get(0));
            }
            return;
        }
        World world = Bukkit.getWorlds().get(0);
        switch (mode) {
            case "lobby" -> buildPremiumLobby(world);
            case "minigames" -> buildMinigames(world);
            case "skyblock" -> prepareHub(world, Material.GRASS_BLOCK, "Skyblock");
            case "prison" -> preparePrisonHub(world);
            case "factions" -> prepareHub(world, Material.GRASS_BLOCK, "Factions");
            case "anarchy" -> prepareHub(world, Material.NETHERRACK, "Anarchy");
            case "survival" -> getLogger().info("Survival готовий.");
            default -> {
            }
        }
        try {
            getDataFolder().mkdirs();
            Files.writeString(marker.toPath(), "ok", StandardCharsets.UTF_8);
        } catch (IOException e) {
            getLogger().warning(e.getMessage());
        }
    }

    /* ===================== PREMIUM LOBBY ===================== */

    private void buildPremiumLobby(World world) {
        world.setSpawnLocation(0, 101, 0);
        world.setGameRule(GameRule.DO_DAYLIGHT_CYCLE, false);
        world.setGameRule(GameRule.DO_WEATHER_CYCLE, false);
        world.setGameRule(GameRule.DO_MOB_SPAWNING, false);
        world.setGameRule(GameRule.ANNOUNCE_ADVANCEMENTS, false);
        world.setTime(18000); // night for neon look
        world.setStorm(false);

        // foundation
        fill(world, -28, 99, -28, 28, 99, 28, Material.BLACK_CONCRETE);
        fill(world, -26, 100, -26, 26, 100, 26, Material.GRAY_CONCRETE);
        // center circle
        disk(world, 0, 100, 0, 8, Material.YELLOW_CONCRETE);
        disk(world, 0, 100, 0, 5, Material.ORANGE_CONCRETE);
        disk(world, 0, 100, 0, 2, Material.RED_CONCRETE);
        world.getBlockAt(0, 101, 0).setType(Material.BEACON, false);
        // beacon base
        fill(world, -1, 100, -1, 1, 100, 1, Material.IRON_BLOCK);

        // colored paths to mode pads
        path(world, 0, 100, 8, 0, 100, 22, Material.LIGHT_BLUE_CONCRETE); // minigames N
        path(world, 0, 100, -8, 0, 100, -22, Material.LIME_CONCRETE); // survival S
        path(world, 8, 100, 0, 22, 100, 0, Material.CYAN_CONCRETE); // skyblock E
        path(world, -8, 100, 0, -22, 100, 0, Material.MAGENTA_CONCRETE); // prison W
        path(world, 12, 100, 12, 20, 100, 20, Material.RED_CONCRETE); // anarchy NE
        path(world, -12, 100, 12, -20, 100, 20, Material.PURPLE_CONCRETE); // factions NW
        path(world, 12, 100, -12, 20, 100, -20, Material.GOLD_BLOCK); // donate SE

        // mode pads
        modePad(world, 0, 100, 24, Material.RED_BED, "MINIGAMES");
        modePad(world, 0, 100, -24, Material.GRASS_BLOCK, "SURVIVAL");
        modePad(world, 24, 100, 0, Material.OAK_SAPLING, "SKYBLOCK");
        modePad(world, -24, 100, 0, Material.IRON_PICKAXE, "PRISON");
        modePad(world, 22, 100, 22, Material.TNT, "ANARCHY");
        modePad(world, -22, 100, 22, Material.DIAMOND_SWORD, "FACTIONS");
        modePad(world, 22, 100, -22, Material.EMERALD, "DONATE");

        // glass ring walls
        for (int x = -28; x <= 28; x++) {
            for (int z = -28; z <= 28; z++) {
                if (Math.abs(x) == 28 || Math.abs(z) == 28) {
                    world.getBlockAt(x, 101, z).setType(Material.BLACK_STAINED_GLASS_PANE, false);
                    world.getBlockAt(x, 102, z).setType(Material.CYAN_STAINED_GLASS_PANE, false);
                    world.getBlockAt(x, 103, z).setType(Material.YELLOW_STAINED_GLASS_PANE, false);
                }
            }
        }
        fill(world, -26, 101, -26, 26, 110, 26, Material.AIR);
        world.getBlockAt(0, 101, 0).setType(Material.BEACON, false);

        // pillars
        for (int[] p : new int[][]{{16, 16}, {-16, 16}, {16, -16}, {-16, -16}}) {
            for (int y = 101; y <= 106; y++) {
                world.getBlockAt(p[0], y, p[1]).setType(Material.QUARTZ_PILLAR, false);
            }
            world.getBlockAt(p[0], 107, p[1]).setType(Material.SEA_LANTERN, false);
        }

        spawnLobbyHolograms(world);
        getLogger().info("Преміум-лобі MineLegacy збудовано.");
    }

    private void modePad(World world, int x, int y, int z, Material icon, String label) {
        fill(world, x - 2, y, z - 2, x + 2, y, z + 2, Material.WHITE_CONCRETE);
        fill(world, x - 1, y, z - 1, x + 1, y, z + 1, Material.BLACK_CONCRETE);
        world.getBlockAt(x, y, z).setType(Material.END_ROD, false);
    }

    private void spawnLobbyHolograms(World world) {
        // clear old
        world.getEntitiesByClass(ArmorStand.class).forEach(a -> {
            if (a.getScoreboardTags().contains("ml_holo")) {
                a.remove();
            }
        });
        holo(world, 0.5, 104, 0.5, "§e§l⚡ §c§lMine§6§lLegacy §e§l⚡");
        holo(world, 0.5, 103.6, 0.5, "§a(1.8–1.21+) §7| §dВиживання ▪ BedWars ▪ Skyblock");
        holo(world, 0.5, 103.2, 0.5, "§bОбери режим нижче або §e/menu");
        holo(world, 0.5, 102.8, 0.5, "§6§l/donate §7— донат і привілеї");

        holo(world, 0.5, 103, 24.5, "§c§lBEDWARS / МІНІ-ІГРИ");
        holo(world, 0.5, 102.6, 24.5, "§7Крокни на платформу → /server minigames");
        holo(world, 0.5, 103, -23.5, "§a§lSURVIVAL");
        holo(world, 24.5, 103, 0.5, "§b§lSKYBLOCK");
        holo(world, -23.5, 103, 0.5, "§6§lPRISON");
        holo(world, 22.5, 103, 22.5, "§4§lANARCHY");
        holo(world, -21.5, 103, 22.5, "§5§lFACTIONS");
        holo(world, 22.5, 103, -21.5, "§6§lДОНАТ §e/donate");
    }

    private void holo(World world, double x, double y, double z, String text) {
        ArmorStand as = (ArmorStand) world.spawnEntity(new Location(world, x, y, z), EntityType.ARMOR_STAND);
        as.setVisible(false);
        as.setGravity(false);
        as.setCustomNameVisible(true);
        as.setCustomName(text);
        as.setMarker(true);
        as.setInvulnerable(true);
        as.addScoreboardTag("ml_holo");
        as.setCollidable(false);
    }

    /* ===================== MINIGAMES ===================== */

    private void buildMinigames(World world) {
        world.setSpawnLocation(0, 121, 0);
        world.setGameRule(GameRule.DO_MOB_SPAWNING, false);
        world.setGameRule(GameRule.DO_DAYLIGHT_CYCLE, false);
        fill(world, -18, 120, -18, 18, 120, 18, Material.BLACK_CONCRETE);
        fill(world, -6, 120, -6, 6, 120, 6, Material.RED_CONCRETE);
        disk(world, 0, 120, 0, 3, Material.YELLOW_CONCRETE);
        fill(world, -18, 121, -18, 18, 130, 18, Material.AIR);
        world.getBlockAt(0, 121, 0).setType(Material.END_ROD, false);
        holo(world, 0.5, 124, 0.5, "§c§lМІНІ-ІГРИ LOBBY");
        holo(world, 0.5, 123.6, 0.5, "§e/bw join TryzubDuo §7— BedWars");
        holo(world, 0.5, 123.2, 0.5, "§7Назад: §a/server lobby");

        int ay = 70, az = 500;
        buildIsland(world, -40, ay, az, Material.RED_WOOL, Material.RED_BED, BlockFace.EAST);
        buildIsland(world, 40, ay, az, Material.BLUE_WOOL, Material.BLUE_BED, BlockFace.WEST);
        fill(world, -3, ay, az - 3, 3, ay, az + 3, Material.STONE_BRICKS);
        writeBedWarsArena(world, ay, az);
        getLogger().info("Лобі міні-ігор + BedWars готові.");
    }

    private void buildIsland(World world, int cx, int y, int cz, Material wool, Material bed, BlockFace facing) {
        fill(world, cx - 6, y, cz - 6, cx + 6, y, cz + 6, Material.SMOOTH_STONE);
        fill(world, cx - 5, y, cz - 5, cx + 5, y, cz + 5, wool);
        placeBed(world, cx, y + 1, cz - 3, bed, facing);
        world.getBlockAt(cx, y + 1, cz + 3).setType(Material.CRAFTING_TABLE, false);
        world.getBlockAt(cx + 1, y + 1, cz + 3).setType(Material.CHEST, false);
    }

    private void placeBed(World world, int x, int y, int z, Material bedMaterial, BlockFace facing) {
        Block foot = world.getBlockAt(x, y, z);
        Block head = foot.getRelative(facing);
        foot.setType(bedMaterial, false);
        head.setType(bedMaterial, false);
        Bed footData = (Bed) foot.getBlockData();
        footData.setPart(Bed.Part.FOOT);
        footData.setFacing(facing);
        foot.setBlockData(footData, false);
        Bed headData = (Bed) head.getBlockData();
        headData.setPart(Bed.Part.HEAD);
        headData.setFacing(facing);
        head.setBlockData(headData, false);
    }

    private void writeBedWarsArena(World world, int ay, int az) {
        File arenas = new File("plugins/BedWars/arenas");
        arenas.mkdirs();
        File file = new File(arenas, "tryzub-duo.yml");
        String w = world.getName();
        int bedY = ay + 1;
        String yaml = ""
            + "name: TryzubDuo\n"
            + "pauseCountdown: 10\n"
            + "gameTime: 3600\n"
            + "world: " + w + "\n"
            + "pos1: -70.0;" + (ay + 40) + ".0;460.0;0.0;0.0\n"
            + "pos2: 70.0;" + (ay - 5) + ".0;540.0;0.0;0.0\n"
            + "specSpawn: 0.5;" + (ay + 10) + ".0;" + az + ".5;0.0;30.0\n"
            + "lobbySpawn: 0.5;121.0;0.5;0.0;0.0\n"
            + "lobbySpawnWorld: " + w + "\n"
            + "minPlayers: 2\n"
            + "postGameWaiting: 10\n"
            + "customPrefix: '&c&lML&7'\n"
            + "teams:\n"
            + "  Red:\n"
            + "    isNewColor: true\n"
            + "    color: RED\n"
            + "    maxPlayers: 4\n"
            + "    bed: -40.0;" + bedY + ".0;" + (az - 3) + ".0;0.0;0.0\n"
            + "    spawn: -40.5;" + bedY + ".0;" + az + ".5;90.0;0.0\n"
            + "    actualName: Червоні\n"
            + "  Blue:\n"
            + "    isNewColor: true\n"
            + "    color: BLUE\n"
            + "    maxPlayers: 4\n"
            + "    bed: 40.0;" + bedY + ".0;" + (az - 3) + ".0;0.0;0.0\n"
            + "    spawn: 40.5;" + bedY + ".0;" + az + ".5;-90.0;0.0\n"
            + "    actualName: Сині\n"
            + "spawners:\n"
            + "- location: 0.5;" + (ay + 1) + ".0;" + az + ".5;0.0;0.0\n"
            + "  type: bronze\n"
            + "  customName: null\n"
            + "  startLevel: 1.0\n"
            + "  hologramEnabled: true\n"
            + "  team: null\n"
            + "  maxSpawnedResources: -1\n"
            + "- location: -40.5;" + (ay + 1) + ".0;" + az + ".5;0.0;0.0\n"
            + "  type: iron\n"
            + "  customName: null\n"
            + "  startLevel: 1.0\n"
            + "  hologramEnabled: true\n"
            + "  team: Red\n"
            + "  maxSpawnedResources: -1\n"
            + "- location: 40.5;" + (ay + 1) + ".0;" + az + ".5;0.0;0.0\n"
            + "  type: iron\n"
            + "  customName: null\n"
            + "  startLevel: 1.0\n"
            + "  hologramEnabled: true\n"
            + "  team: Blue\n"
            + "  maxSpawnedResources: -1\n"
            + "- location: 0.5;" + (ay + 1) + ".0;" + az + ".5;0.0;0.0\n"
            + "  type: gold\n"
            + "  customName: null\n"
            + "  startLevel: 1.0\n"
            + "  hologramEnabled: true\n"
            + "  team: null\n"
            + "  maxSpawnedResources: -1\n"
            + "stores:\n"
            + "- loc: -38.5;" + (ay + 1) + ".0;" + az + ".5;0.0;0.0\n"
            + "  shop: shop.yml\n"
            + "  parent: 'true'\n"
            + "  type: VILLAGER\n"
            + "  name: '&aКрамниця'\n"
            + "  isBaby: 'false'\n"
            + "  skin: null\n"
            + "  team: Red\n"
            + "- loc: 38.5;" + (ay + 1) + ".0;" + az + ".5;180.0;0.0\n"
            + "  shop: shop.yml\n"
            + "  parent: 'true'\n"
            + "  type: VILLAGER\n"
            + "  name: '&aКрамниця'\n"
            + "  isBaby: 'false'\n"
            + "  skin: null\n"
            + "  team: Blue\n";
        try {
            Files.writeString(file.toPath(), yaml, StandardCharsets.UTF_8);
        } catch (IOException e) {
            getLogger().severe(e.getMessage());
        }
    }

    private void prepareHub(World world, Material floor, String name) {
        world.setSpawnLocation(0, 101, 0);
        fill(world, -12, 100, -12, 12, 100, 12, floor);
        fill(world, -12, 101, -12, 12, 110, 12, Material.AIR);
        holo(world, 0.5, 103, 0.5, "§e§l" + name);
        getLogger().info("Хаб " + name + " готовий.");
    }

    private void preparePrisonHub(World world) {
        prepareHub(world, Material.STONE_BRICKS, "Prison");
        fill(world, 30, 60, -10, 50, 80, 10, Material.STONE);
        fill(world, 32, 62, -8, 48, 78, 8, Material.AIR);
        for (int i = 0; i < 80; i++) {
            world.getBlockAt(32 + (i * 7) % 16, 62 + (i * 3) % 16, -8 + (i * 5) % 16)
                .setType(Material.COAL_ORE, false);
        }
    }

    /* ===================== DONATE / MENU ===================== */

    private void openMenu(Player p) {
        Inventory inv = Bukkit.createInventory(null, 27, "§c§lMine§6§lLegacy §8| §fРежими");
        inv.setItem(10, item(Material.RED_BED, "§c§lМіні-ігри / BedWars", "§7/server minigames", "§eКлік → перехід"));
        inv.setItem(11, item(Material.GRASS_BLOCK, "§a§lSurvival", "§7Класичне виживання", "§e/server survival"));
        inv.setItem(12, item(Material.OAK_SAPLING, "§b§lSkyblock", "§7Острів у небі", "§e/server skyblock"));
        inv.setItem(13, item(Material.IRON_PICKAXE, "§6§lPrison", "§7Шахти та ранги", "§e/server prison"));
        inv.setItem(14, item(Material.DIAMOND_SWORD, "§5§lFactions", "§7Війни кланів", "§e/server factions"));
        inv.setItem(15, item(Material.TNT, "§4§lAnarchy", "§7Без правил PvP", "§e/server anarchy"));
        inv.setItem(16, item(Material.EMERALD, "§6§lДонат", "§7Привілеї та монети", "§e/donate"));
        inv.setItem(22, item(Material.NETHER_STAR, "§e§lЛобі", "§7Повернутись", "§e/server lobby"));
        p.openInventory(inv);
    }

    private void openDonate(Player p) {
        int bal = getCoins(p.getUniqueId());
        Inventory inv = Bukkit.createInventory(null, 27, "§6§lДОНАТ §8| §e" + bal + " монет");
        inv.setItem(10, item(Material.IRON_INGOT, "§a§lVIP §7— §e500",
            "§7Префікс VIP, /fly на лобі", "§7Кіт VIP", "§eКлік щоб купити"));
        inv.setItem(12, item(Material.GOLD_INGOT, "§b§lPREMIUM §7— §e1500",
            "§7Все з VIP", "§7Більше домівок", "§eКлік щоб купити"));
        inv.setItem(14, item(Material.DIAMOND, "§d§lLEGEND §7— §e4000",
            "§7Все з Premium", "§7Майже адмін-косметика", "§eКлік щоб купити"));
        inv.setItem(16, item(Material.NETHERITE_INGOT, "§c§lSPONSOR §7— §e10000",
            "§7Макс. донат-ранг", "§7Унікальний префікс", "§eКлік щоб купити"));
        inv.setItem(22, item(Material.PAPER, "§eЯк отримати монети?",
            "§7Напиши адміну після оплати", "§7Або: §f/coins give <нік> <сума>",
            "§7Тест: §a/coins give " + p.getName() + " 5000"));
        p.openInventory(inv);
        p.playSound(p.getLocation(), Sound.BLOCK_NOTE_BLOCK_PLING, 1f, 1.2f);
    }

    private ItemStack item(Material mat, String name, String... loreLines) {
        ItemStack stack = new ItemStack(mat);
        ItemMeta meta = stack.getItemMeta();
        meta.setDisplayName(name);
        meta.setLore(Arrays.asList(loreLines));
        stack.setItemMeta(meta);
        return stack;
    }

    @EventHandler
    public void onInvClick(InventoryClickEvent e) {
        if (!(e.getWhoClicked() instanceof Player p)) return;
        String title = e.getView().getTitle();
        if (title == null) return;
        if (title.contains("Режими") || title.contains("ДОНАТ")) {
            e.setCancelled(true);
            ItemStack cur = e.getCurrentItem();
            if (cur == null || !cur.hasItemMeta()) return;
            String name = cur.getItemMeta().getDisplayName();
            if (title.contains("Режими")) {
                if (name.contains("Міні-ігри")) connect(p, "minigames");
                else if (name.contains("Survival")) connect(p, "survival");
                else if (name.contains("Skyblock")) connect(p, "skyblock");
                else if (name.contains("Prison")) connect(p, "prison");
                else if (name.contains("Factions")) connect(p, "factions");
                else if (name.contains("Anarchy")) connect(p, "anarchy");
                else if (name.contains("Донат")) { p.closeInventory(); openDonate(p); }
                else if (name.contains("Лобі")) connect(p, "lobby");
            } else if (title.contains("ДОНАТ")) {
                if (name.contains("VIP")) buyRank(p, "vip", 500);
                else if (name.contains("PREMIUM")) buyRank(p, "premium", 1500);
                else if (name.contains("LEGEND")) buyRank(p, "legend", 4000);
                else if (name.contains("SPONSOR")) buyRank(p, "sponsor", 10000);
            }
        }
    }

    private void buyRank(Player p, String rank, int price) {
        int bal = getCoins(p.getUniqueId());
        if (bal < price) {
            p.sendMessage("§cНедостатньо монет! Є §e" + bal + "§c, потрібно §e" + price);
            p.sendMessage("§7Адмін видає монети: §f/coins give " + p.getName() + " " + price);
            p.playSound(p.getLocation(), Sound.ENTITY_VILLAGER_NO, 1f, 1f);
            return;
        }
        setCoins(p.getUniqueId(), bal - price);
        Bukkit.dispatchCommand(Bukkit.getConsoleSender(), "lp user " + p.getName() + " parent set " + rank);
        p.sendMessage("§a§lДякуємо за донат! §fРанг §e" + rank.toUpperCase(Locale.ROOT) + " §fактивовано.");
        p.playSound(p.getLocation(), Sound.UI_TOAST_CHALLENGE_COMPLETE, 1f, 1f);
        p.closeInventory();
        Bukkit.broadcastMessage("§6§l[Донат] §e" + p.getName() + " §fкупив §6" + rank.toUpperCase(Locale.ROOT) + "§f!");
    }

    private void connect(Player p, String server) {
        p.closeInventory();
        p.sendMessage("§7Підключення до §e" + server + "§7...");
        try {
            java.io.ByteArrayOutputStream b = new java.io.ByteArrayOutputStream();
            java.io.DataOutputStream out = new java.io.DataOutputStream(b);
            out.writeUTF("Connect");
            out.writeUTF(server);
            p.sendPluginMessage(this, "BungeeCord", b.toByteArray());
        } catch (Exception ex) {
            p.performCommand("server " + server);
        }
    }

    @EventHandler
    public void onJoin(PlayerJoinEvent event) {
        Player p = event.getPlayer();
        // register channel once
        try {
            if (!Bukkit.getMessenger().getOutgoingChannels(this).contains("BungeeCord")) {
                Bukkit.getMessenger().registerOutgoingPluginChannel(this, "BungeeCord");
            }
        } catch (Exception ignored) {
        }

        if ("lobby".equals(mode)) {
            event.setJoinMessage("§a✔ §e" + p.getName() + " §7зайшов на §cMine§6Legacy");
            Bukkit.getScheduler().runTaskLater(this, () -> {
                p.teleport(new Location(p.getWorld(), 0.5, 101, 0.5, 0, 0));
                p.sendMessage("§e§l⚡ §c§lMine§6§lLegacy §e§l⚡");
                p.sendMessage("§7Режими: §e/menu §7| Донат: §6/donate §7| Монети: §e/coins");
                p.getInventory().setItem(4, item(Material.COMPASS, "§e§lМеню режимів", "§7ПКМ — відкрити"));
                p.getInventory().setItem(8, item(Material.EMERALD, "§6§lДонат", "§7ПКМ — /donate"));
            }, 15L);
        } else {
            String tip = switch (mode) {
                case "minigames" -> "§cBedWars: §e/bw join TryzubDuo §7| §a/server lobby";
                case "skyblock" -> "§b/is create §7— створити острів";
                case "prison" -> "§6/ranks §7| §6/mines";
                case "factions" -> "§5/f create <назва>";
                case "anarchy" -> "§4Anarchy: PvP увімкнено, правил майже немає.";
                case "survival" -> "§a/sethome §7| §a/claim";
                default -> "§eMineLegacy";
            };
            event.setJoinMessage("§a+ §f" + p.getName());
            Bukkit.getScheduler().runTaskLater(this, () -> p.sendMessage(tip), 20L);
        }
    }

    @EventHandler
    public void onInteract(PlayerInteractEvent e) {
        if (!"lobby".equals(mode)) return;
        if (e.getAction() != Action.RIGHT_CLICK_AIR && e.getAction() != Action.RIGHT_CLICK_BLOCK) return;
        Player p = e.getPlayer();
        ItemStack hand = p.getInventory().getItemInMainHand();
        if (hand == null || !hand.hasItemMeta()) return;
        String n = hand.getItemMeta().getDisplayName();
        if (n != null && n.contains("Меню")) {
            e.setCancelled(true);
            openMenu(p);
        } else if (n != null && n.contains("Донат")) {
            e.setCancelled(true);
            openDonate(p);
        }
    }

    @EventHandler
    public void onMovePad(org.bukkit.event.player.PlayerMoveEvent e) {
        if (!"lobby".equals(mode)) return;
        if (e.getTo() == null) return;
        if (e.getFrom().getBlockX() == e.getTo().getBlockX()
            && e.getFrom().getBlockZ() == e.getTo().getBlockZ()) return;
        Player p = e.getPlayer();
        long now = System.currentTimeMillis();
        if (now - clickCooldown.getOrDefault(p.getUniqueId(), 0L) < 1500) return;
        int x = e.getTo().getBlockX();
        int z = e.getTo().getBlockZ();
        int y = e.getTo().getBlockY();
        if (y < 100 || y > 103) return;
        String server = null;
        if (near(x, z, 0, 24)) server = "minigames";
        else if (near(x, z, 0, -24)) server = "survival";
        else if (near(x, z, 24, 0)) server = "skyblock";
        else if (near(x, z, -24, 0)) server = "prison";
        else if (near(x, z, 22, 22)) server = "anarchy";
        else if (near(x, z, -22, 22)) server = "factions";
        else if (near(x, z, 22, -22)) {
            clickCooldown.put(p.getUniqueId(), now);
            openDonate(p);
            return;
        }
        if (server != null) {
            clickCooldown.put(p.getUniqueId(), now);
            connect(p, server);
        }
    }

    private boolean near(int x, int z, int tx, int tz) {
        return Math.abs(x - tx) <= 2 && Math.abs(z - tz) <= 2;
    }

    /* ===================== COINS ===================== */

    private int getCoins(UUID id) {
        return coins.getInt(id.toString(), 0);
    }

    private void setCoins(UUID id, int amount) {
        coins.set(id.toString(), Math.max(0, amount));
        saveCoins();
    }

    private void saveCoins() {
        try {
            coins.save(coinsFile);
        } catch (IOException e) {
            getLogger().warning("coins save: " + e.getMessage());
        }
    }

    /* ===================== COMMANDS ===================== */

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        String cmd = command.getName().toLowerCase(Locale.ROOT);
        if (cmd.equals("menu") || cmd.equals("servers")) {
            if (sender instanceof Player p) openMenu(p);
            else sender.sendMessage("Лише для гравців");
            return true;
        }
        if (cmd.equals("donate") || cmd.equals("donat") || cmd.equals("shop")) {
            if (sender instanceof Player p) openDonate(p);
            else sender.sendMessage("Лише для гравців");
            return true;
        }
        if (cmd.equals("coins")) {
            if (args.length == 0 && sender instanceof Player p) {
                p.sendMessage("§eВаш баланс: §6" + getCoins(p.getUniqueId()) + " §eмонет");
                return true;
            }
            if (args.length >= 3 && args[0].equalsIgnoreCase("give") && sender.hasPermission("tryzub.coins")) {
                Player t = Bukkit.getPlayerExact(args[1]);
                int amt;
                try { amt = Integer.parseInt(args[2]); } catch (Exception ex) {
                    sender.sendMessage("§cЧисло?");
                    return true;
                }
                UUID id = t != null ? t.getUniqueId() : Bukkit.getOfflinePlayer(args[1]).getUniqueId();
                setCoins(id, getCoins(id) + amt);
                sender.sendMessage("§aВидано §e" + amt + " §aмонет гравцю §f" + args[1]);
                if (t != null) t.sendMessage("§aВи отримали §e" + amt + " §aдонат-монет!");
                return true;
            }
            sender.sendMessage("§e/coins §7| §e/coins give <нік> <сума>");
            return true;
        }
        if (cmd.equals("tryzubsetup")) {
            if (!sender.hasPermission("tryzub.setup")) {
                sender.sendMessage("§cНемає прав.");
                return true;
            }
            if (args.length > 0 && args[0].equalsIgnoreCase("rebuild")) {
                getConfig().set("force-rebuild", true);
                saveConfig();
                //noinspection ResultOfMethodCallIgnored
                new File(getDataFolder(), "bootstrapped.flag").delete();
                bootstrap();
                getConfig().set("force-rebuild", false);
                saveConfig();
                sender.sendMessage("§aПеребудовано.");
                return true;
            }
            sender.sendMessage("§e/tryzubsetup rebuild");
            return true;
        }
        return false;
    }

    /* ===================== UTILS ===================== */

    private void fill(World world, int x1, int y1, int z1, int x2, int y2, int z2, Material mat) {
        int minX = Math.min(x1, x2), maxX = Math.max(x1, x2);
        int minY = Math.min(y1, y2), maxY = Math.max(y1, y2);
        int minZ = Math.min(z1, z2), maxZ = Math.max(z1, z2);
        for (int x = minX; x <= maxX; x++) {
            for (int y = minY; y <= maxY; y++) {
                for (int z = minZ; z <= maxZ; z++) {
                    world.getBlockAt(x, y, z).setType(mat, false);
                }
            }
        }
    }

    private void disk(World world, int cx, int y, int cz, int r, Material mat) {
        for (int x = -r; x <= r; x++) {
            for (int z = -r; z <= r; z++) {
                if (x * x + z * z <= r * r) {
                    world.getBlockAt(cx + x, y, cz + z).setType(mat, false);
                }
            }
        }
    }

    private void path(World world, int x1, int y1, int z1, int x2, int y2, int z2, Material mat) {
        int dx = Integer.compare(x2, x1);
        int dz = Integer.compare(z2, z1);
        int x = x1, z = z1;
        while (true) {
            world.getBlockAt(x, y1, z).setType(mat, false);
            if (x == x2 && z == z2) break;
            if (x != x2) x += dx;
            if (z != z2) z += dz;
        }
    }
}
