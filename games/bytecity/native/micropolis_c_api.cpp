#include "micropolis_c_api.h"
#define private public
#define protected public
#include "micropolis.h"
#undef private
#undef protected
#include "text.h"

#include <queue>
#include <string>
#include <vector>
#include <cstring>

static const char* get_message_text(int index) {
    switch (index) {
        case MESSAGE_NEED_MORE_RESIDENTIAL: return "Citizens demand more Residential zones.";
        case MESSAGE_NEED_MORE_COMMERCIAL: return "Commerce demands more Commercial zones.";
        case MESSAGE_NEED_MORE_INDUSTRIAL: return "Industry demands more Industrial zones.";
        case MESSAGE_NEED_MORE_ROADS: return "Traffic gridlock! Build more roads.";
        case MESSAGE_NEED_MORE_RAILS: return "Mass transit needed! Build railroads.";
        case MESSAGE_NEED_ELECTRICITY: return "Power lines needed to conduct electricity.";
        case MESSAGE_NEED_SEAPORT: return "Industry requires a Sea Port.";
        case MESSAGE_NEED_AIRPORT: return "Commerce requires an Airport.";
        case MESSAGE_HIGH_POLLUTION: return "Pollution levels are dangerously high!";
        case MESSAGE_HIGH_CRIME: return "Crime is rampant! Build police stations.";
        case MESSAGE_TRAFFIC_JAMS: return "Heavy traffic jams reported throughout the city.";
        case MESSAGE_NEED_FIRE_STATION: return "Citizens demand a Fire Department.";
        case MESSAGE_NEED_POLICE_STATION: return "Citizens demand a Police Department.";
        case MESSAGE_BLACKOUTS_REPORTED: return "Blackouts reported! Check your power grid.";
        case MESSAGE_TAX_TOO_HIGH: return "Citizens are angry: taxes are too high!";
        case MESSAGE_ROAD_NEEDS_FUNDING: return "Roads deteriorating due to lack of maintenance funds.";
        case MESSAGE_FIRE_STATION_NEEDS_FUNDING: return "Fire departments urgently need funding.";
        case MESSAGE_POLICE_NEEDS_FUNDING: return "Police departments urgently need funding.";
        case MESSAGE_FIRE_REPORTED: return "Fire reported in the city!";
        case MESSAGE_MONSTER_SIGHTED: return "A Monster has appeared!";
        case MESSAGE_TORNADO_SIGHTED: return "Tornado spotted touching down!";
        case MESSAGE_EARTHQUAKE: return "Major earthquake shaking the city!";
        case MESSAGE_PLANE_CRASHED: return "Plane crash reported!";
        case MESSAGE_SHIP_CRASHED: return "Shipwreck reported along the coast!";
        case MESSAGE_TRAIN_CRASHED: return "Train derailment reported!";
        case MESSAGE_HIGH_UNEMPLOYMENT: return "Unemployment rate is high.";
        case MESSAGE_NO_MONEY: return "Warning: City has run out of funds!";
        case MESSAGE_NEED_MORE_PARKS: return "Citizens demand more parks and green space.";
        case MESSAGE_NOT_ENOUGH_POWER: return "Brownouts reported: build another power plant!";
        case MESSAGE_NUCLEAR_MELTDOWN: return "DISASTER: Nuclear meltdown occurred!";
        case MESSAGE_FLOODING_REPORTED: return "Flooding reported along riverbanks!";
        case MESSAGE_REACHED_TOWN: return "Milestone: Population has reached 2,000! (Town)";
        case MESSAGE_REACHED_CITY: return "Milestone: Population has reached 10,000! (City)";
        case MESSAGE_REACHED_CAPITAL: return "Milestone: Population has reached 50,000! (Capital)";
        case MESSAGE_REACHED_METROPOLIS: return "Milestone: Population has reached 100,000! (Metropolis)";
        case MESSAGE_REACHED_MEGALOPOLIS: return "Milestone: Population has reached 500,000! (Megalopolis)";
        default: return nullptr;
    }
}

class ByteCityCallback : public Callback {
public:
    std::queue<std::string> messages;
    std::string current_message;

    virtual ~ByteCityCallback() {}

    virtual void sendMessage(Micropolis *micropolis, emscripten::val callbackVal, int messageIndex, int x, int y, bool picture, bool important) override {
        const char* txt = get_message_text(messageIndex);
        if (txt != nullptr) {
            messages.push(std::string(txt));
        }
    }

    // Default no-ops for unused callbacks
    virtual void autoGoto(Micropolis *m, emscripten::val v, int x, int y, std::string msg) override {}
    virtual void didGenerateMap(Micropolis *m, emscripten::val v, int seed) override {}
    virtual void didLoadCity(Micropolis *m, emscripten::val v, std::string f) override {}
    virtual void didLoadScenario(Micropolis *m, emscripten::val v, std::string n, std::string f) override {}
    virtual void didLoseGame(Micropolis *m, emscripten::val v) override {}
    virtual void didSaveCity(Micropolis *m, emscripten::val v, std::string f) override {}
    virtual void didTool(Micropolis *m, emscripten::val v, std::string name, int x, int y) override {}
    virtual void didWinGame(Micropolis *m, emscripten::val v) override {}
    virtual void didntLoadCity(Micropolis *m, emscripten::val v, std::string f) override {}
    virtual void didntSaveCity(Micropolis *m, emscripten::val v, std::string f) override {}
    virtual void makeSound(Micropolis *m, emscripten::val v, std::string ch, std::string snd, int x, int y) override {}
    virtual void newGame(Micropolis *m, emscripten::val v) override {}
    virtual void saveCityAs(Micropolis *m, emscripten::val v, std::string f) override {}
    virtual void showBudgetAndWait(Micropolis *m, emscripten::val v) override {}
    virtual void showZoneStatus(Micropolis *m, emscripten::val v, int c, int p, int l, int cr, int pol, int g, int x, int y) override {}
    virtual void simulateRobots(Micropolis *m, emscripten::val v) override {}
    virtual void simulateChurch(Micropolis *m, emscripten::val v, int x, int y, int ch) override {}
    virtual void startEarthquake(Micropolis *m, emscripten::val v, int str) override {}
    virtual void startGame(Micropolis *m, emscripten::val v) override {}
    virtual void startScenario(Micropolis *m, emscripten::val v, int sc) override {}
    virtual void updateBudget(Micropolis *m, emscripten::val v) override {}
    virtual void updateCityName(Micropolis *m, emscripten::val v, std::string name) override {}
    virtual void updateDate(Micropolis *m, emscripten::val v, int y, int m2) override {}
    virtual void updateDemand(Micropolis *m, emscripten::val v, float r, float c, float i) override {}
    virtual void updateEvaluation(Micropolis *m, emscripten::val v) override {}
    virtual void updateFunds(Micropolis *m, emscripten::val v, int f) override {}
    virtual void updateGameLevel(Micropolis *m, emscripten::val v, int l) override {}
    virtual void updateHistory(Micropolis *m, emscripten::val v) override {}
    virtual void updateMap(Micropolis *m, emscripten::val v) override {}
    virtual void updateOptions(Micropolis *m, emscripten::val v) override {}
    virtual void updatePasses(Micropolis *m, emscripten::val v, int p) override {}
    virtual void updatePaused(Micropolis *m, emscripten::val v, bool p) override {}
    virtual void updateSpeed(Micropolis *m, emscripten::val v, int s) override {}
    virtual void updateTaxRate(Micropolis *m, emscripten::val v, int t) override {}
};

struct ByteCityContext {
    Micropolis* sim;
    ByteCityCallback* callback;
};

extern "C" {

ByteCityHandle bytecity_create(void) {
    ByteCityContext* ctx = new ByteCityContext();
    ctx->sim = new Micropolis();
    ctx->sim->callback = nullptr;
    ctx->callback = new ByteCityCallback();
    ctx->sim->setCallback(ctx->callback, emscripten::val::null());
    ctx->sim->init();
    ctx->sim->totalFunds = 20000;
    ctx->sim->cityTax = 7;
    ctx->sim->autoBulldoze = true;
    ctx->sim->autoBudget = false;
    ctx->sim->simSpeed = 1;
    return (ByteCityHandle)ctx;
}

void bytecity_destroy(ByteCityHandle handle) {
    if (!handle) return;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    delete ctx->sim;
    // callback is deleted by Micropolis destructor or setCallback
    delete ctx;
}

void bytecity_generate_map(ByteCityHandle handle, int seed) {
    if (!handle) return;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    ctx->sim->generateMap(seed);
    ctx->sim->totalFunds = 20000;
    ctx->sim->cityTax = 7;
    ctx->sim->autoBulldoze = true;
    ctx->sim->autoBudget = false;

    // Ensure all shoreline edges, trees, and rubble have BULLBIT set
    // so they are fully buildable and bulldozable by the player.
    for (int x = 0; x < WORLD_W; ++x) {
        for (int y = 0; y < WORLD_H; ++y) {
            uint16_t t = ctx->sim->map[x][y] & LOMASK;
            if ((t >= FIRSTRIVEDGE && t <= LASTRUBBLE) || (t >= TINYEXP && t <= LASTTINYEXP)) {
                ctx->sim->map[x][y] |= BULLBIT;
            }
        }
    }
}

void bytecity_tick(ByteCityHandle handle) {
    if (!handle) return;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    ctx->sim->simTick();
    bytecity_refresh_power(handle);
}

void bytecity_set_speed(ByteCityHandle handle, int speed) {
    if (!handle) return;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    ctx->sim->simSpeed = speed;
}

uint16_t bytecity_get_tile(ByteCityHandle handle, int x, int y) {
    if (!handle) return 0;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    if (x < 0 || x >= WORLD_W || y < 0 || y >= WORLD_H) return 0;
    return ctx->sim->map[x][y];
}

const uint16_t* bytecity_get_map_ptr(ByteCityHandle handle) {
    if (!handle) return nullptr;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    return (const uint16_t*)ctx->sim->mapBase;
}

const uint8_t* bytecity_get_power_map_ptr(ByteCityHandle handle) {
    if (!handle) return nullptr;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    return (const uint8_t*)ctx->sim->powerGridMap.getBase();
}

void bytecity_copy_map(ByteCityHandle handle, uint16_t* dest_buffer) {
    if (!handle || !dest_buffer) return;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    for (int x = 0; x < WORLD_W; ++x) {
        std::memcpy(dest_buffer + (x * WORLD_H), ctx->sim->map[x], WORLD_H * sizeof(uint16_t));
    }
}

static bool get_building_box(ByteCityContext* ctx, int x, int y, int& leftX, int& topY, int& size) {
    uint16_t raw = ctx->sim->map[x][y];
    uint16_t t = raw & LOMASK;

    // Check 3x3 zones (R 240..422, C 423..611, I 612..692, Fire 761..769, Police 770..778)
    if ((t >= 240 && t <= 692) || (t >= 761 && t <= 778)) {
        size = 3;
        for (int dx = -1; dx <= 1; ++dx) {
            for (int dy = -1; dy <= 1; ++dy) {
                int cx = x + dx;
                int cy = y + dy;
                if (cx >= 0 && cx < WORLD_W && cy >= 0 && cy < WORLD_H) {
                    if (ctx->sim->map[cx][cy] & ZONEBIT) {
                        leftX = cx - 1;
                        topY = cy - 1;
                        return true;
                    }
                }
            }
        }
        leftX = x - 1;
        topY = y - 1;
        return true;
    }

    // Check 4x4 zones (Coal 745..760, Stadium 779..794, Nuclear 811..826, Seaport 827..842)
    if ((t >= 745 && t <= 760) || (t >= 779 && t <= 794) || (t >= 811 && t <= 842)) {
        size = 4;
        for (int dx = -2; dx <= 2; ++dx) {
            for (int dy = -2; dy <= 2; ++dy) {
                int cx = x + dx;
                int cy = y + dy;
                if (cx >= 0 && cx < WORLD_W && cy >= 0 && cy < WORLD_H) {
                    if (ctx->sim->map[cx][cy] & ZONEBIT) {
                        leftX = cx - 1;
                        topY = cy - 1;
                        return true;
                    }
                }
            }
        }
        leftX = x - 1;
        topY = y - 1;
        return true;
    }

    // Check 6x6 Airport (843..878)
    if (t >= 843 && t <= 878) {
        size = 6;
        for (int dx = -3; dx <= 3; ++dx) {
            for (int dy = -3; dy <= 3; ++dy) {
                int cx = x + dx;
                int cy = y + dy;
                if (cx >= 0 && cx < WORLD_W && cy >= 0 && cy < WORLD_H) {
                    if (ctx->sim->map[cx][cy] & ZONEBIT) {
                        leftX = cx - 1;
                        topY = cy - 1;
                        return true;
                    }
                }
            }
        }
        leftX = x - 2;
        topY = y - 2;
        return true;
    }

    return false;
}

int bytecity_do_tool(ByteCityHandle handle, int tool_id, int x, int y) {
    if (!handle) return BYTECITY_TOOL_FAILED;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    if (x < 0 || x >= WORLD_W || y < 0 || y >= WORLD_H) return BYTECITY_TOOL_FAILED;

    // Always ensure autoBulldoze is active so building on terrain auto-clears trees
    ctx->sim->autoBulldoze = true;

    // In Micropolis, building tools expect the center tile and subtract 1 internally.
    // To place a multi-tile building with its top-left at (x, y), we pass (x + 1, y + 1).
    short targetX = (short)x;
    short targetY = (short)y;
    bool is_building = (tool_id == 0 || tool_id == 1 || tool_id == 2 ||
                        tool_id == 3 || tool_id == 4 || tool_id == 10 ||
                        tool_id == 12 || tool_id == 13 || tool_id == 14 ||
                        tool_id == 15);
    if (is_building) {
        targetX += 1;
        targetY += 1;
    }

    // Bulldozer special handling: clean clear of entire buildings, rubble, shorelines, and dirt
    if (tool_id == 7) { // BC_TOOL_BULLDOZER
        uint16_t raw = ctx->sim->map[targetX][targetY];
        uint16_t t = raw & LOMASK;

        // 1. If it's already dirt, smooth sweep
        if (t == DIRT) {
            if (ctx->sim->totalFunds > 0) ctx->sim->totalFunds -= 1;
            return BYTECITY_TOOL_OK;
        }

        // 2. If it's rubble or fire, clear to DIRT immediately
        if ((t >= 44 && t <= 51)) {
            ctx->sim->map[targetX][targetY] = DIRT;
            if (ctx->sim->totalFunds > 0) ctx->sim->totalFunds -= 1;
            return BYTECITY_TOOL_OK;
        }

        // 3. Check if it's any zone building (center or outer tile)
        int bLeft = 0, bTop = 0, bSize = 0;
        if (get_building_box(ctx, targetX, targetY, bLeft, bTop, bSize)) {
            int cost = 10;
            if (ctx->sim->totalFunds < cost) return BYTECITY_TOOL_NO_MONEY;
            ctx->sim->totalFunds -= cost;

            // Clear ALL tiles of this building directly to DIRT! No leftover boxes or rubble!
            for (int bx = bLeft; bx < bLeft + bSize; ++bx) {
                for (int by = bTop; by < bTop + bSize; ++by) {
                    if (bx >= 0 && bx < WORLD_W && by >= 0 && by < WORLD_H) {
                        ctx->sim->map[bx][by] = DIRT;
                    }
                }
            }
            bytecity_refresh_power(handle);
            return BYTECITY_TOOL_OK;
        }

        // 4. Shorelines or trees: ensure BULLBIT is set so layDoze succeeds
        if ((t >= FIRSTRIVEDGE && t <= LASTRUBBLE) || (t >= TINYEXP && t <= LASTTINYEXP)) {
            ctx->sim->map[targetX][targetY] |= BULLBIT;
        }
    }

    int res = (int)ctx->sim->doTool((EditingTool)tool_id, targetX, targetY);

    if (res == 1) {
        bytecity_refresh_power(handle);
    }

    return res;
}

void bytecity_refresh_power(ByteCityHandle handle) {
    if (!handle) return;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    if (!ctx->sim) return;

    // Reset power stack and power generator counts
    ctx->sim->powerStackPointer = 0;
    ctx->sim->coalPowerPop = 0;
    ctx->sim->nuclearPowerPop = 0;

    // Scan map for Coal and Nuclear power plant centers
    for (int x = 0; x < WORLD_W; ++x) {
        for (int y = 0; y < WORLD_H; ++y) {
            uint16_t t = ctx->sim->map[x][y] & LOMASK;
            if (t == POWERPLANT) { // Coal power plant center (tile 750)
                ctx->sim->coalPowerPop++;
                ctx->sim->pushPowerStack(Position(x, y));
            } else if (t == NUCLEAR) { // Nuclear power plant center (tile 816)
                ctx->sim->nuclearPowerPop++;
                ctx->sim->pushPowerStack(Position(x, y));
            }
        }
    }

    // Flood-fill electricity across all conductive tiles (wires, roads, buildings)
    ctx->sim->doPowerScan();

    // Propagate PWRBIT to every zone center that receives electricity
    for (int zx = 0; zx < WORLD_W; ++zx) {
        for (int zy = 0; zy < WORLD_H; ++zy) {
            if (ctx->sim->map[zx][zy] & ZONEBIT) {
                Position p(zx, zy);
                ctx->sim->setZonePower(p);
            }
        }
    }
}

bool bytecity_has_power(ByteCityHandle handle, int x, int y) {
    if (!handle || x < 0 || x >= WORLD_W || y < 0 || y >= WORLD_H) return false;
    ByteCityContext* ctx = (ByteCityContext*)handle;

    uint16_t raw = ctx->sim->map[x][y];
    uint16_t t = raw & LOMASK;

    // Power plants are self-powered
    if ((t >= COALBASE && t <= LASTPOWERPLANT) || (t >= NUCLEARBASE && t <= NUCLEARBASE + 15)) {
        return true;
    }

    if (raw & PWRBIT) return true;
    if (ctx->sim->powerGridMap.worldGet(x, y) != 0) return true;

    // Check if the parent building has power
    int bLeft = 0, bTop = 0, bSize = 0;
    if (get_building_box(ctx, x, y, bLeft, bTop, bSize)) {
        int cx = bLeft + (bSize >= 3 ? 1 : 0);
        int cy = bTop + (bSize >= 3 ? 1 : 0);
        if (cx >= 0 && cx < WORLD_W && cy >= 0 && cy < WORLD_H) {
            if (ctx->sim->map[cx][cy] & PWRBIT) return true;
            if (ctx->sim->powerGridMap.worldGet(cx, cy) != 0) return true;
        }
        for (int bx = bLeft; bx < bLeft + bSize; ++bx) {
            for (int by = bTop; by < bTop + bSize; ++by) {
                if (bx >= 0 && bx < WORLD_W && by >= 0 && by < WORLD_H) {
                    if (ctx->sim->powerGridMap.worldGet(bx, by) != 0) return true;
                }
            }
        }
    }

    return false;
}

int64_t bytecity_get_funds(ByteCityHandle handle) {
    if (!handle) return 0;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    return (int64_t)ctx->sim->totalFunds;
}

void bytecity_set_funds(ByteCityHandle handle, int64_t funds) {
    if (!handle) return;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    ctx->sim->totalFunds = (Quad)funds;
}

int bytecity_get_tax_rate(ByteCityHandle handle) {
    if (!handle) return 7;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    return (int)ctx->sim->cityTax;
}

void bytecity_set_tax_rate(ByteCityHandle handle, int rate) {
    if (!handle) return;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    ctx->sim->cityTax = (short)rate;
}

int bytecity_get_population(ByteCityHandle handle) {
    if (!handle) return 0;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    Quad pop = ctx->sim->getPopulation();
    if (pop > 0) return (int)pop;

    // Direct scan fallback: accurately count citizens living in active houses & zones
    int citizenCount = 0;
    for (int x = 0; x < WORLD_W; ++x) {
        for (int y = 0; y < WORLD_H; ++y) {
            uint16_t t = ctx->sim->map[x][y] & LOMASK;
            if (t >= HOUSE && t <= HHTHR) {
                // Single tile houses (10 to 80 residents per tile)
                citizenCount += (t - HOUSE + 1) * 16;
            } else if (t >= RZB && t < HOSPITALBASE) {
                if (ctx->sim->map[x][y] & ZONEBIT) {
                    citizenCount += 120;
                }
            } else if (t >= CZB && t < INDBASE) {
                if (ctx->sim->map[x][y] & ZONEBIT) {
                    citizenCount += 80;
                }
            } else if (t >= IZB && t < PORTBASE) {
                if (ctx->sim->map[x][y] & ZONEBIT) {
                    citizenCount += 60;
                }
            }
        }
    }
    return citizenCount;
}

int bytecity_get_year(ByteCityHandle handle) {
    if (!handle) return 1900;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    return (int)((ctx->sim->cityTime / 48) + ctx->sim->startingYear);
}

int bytecity_get_month(ByteCityHandle handle) {
    if (!handle) return 0;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    return (int)((ctx->sim->cityTime % 48) / 4); // 0 = Jan .. 11 = Dec
}

void bytecity_get_demand(ByteCityHandle handle, float* res, float* com, float* ind) {
    if (!handle) return;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    if (res) *res = (float)ctx->sim->resValve;
    if (com) *com = (float)ctx->sim->comValve;
    if (ind) *ind = (float)ctx->sim->indValve;
}

int bytecity_get_city_yes(ByteCityHandle handle) {
    if (!handle) return 50;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    return (int)ctx->sim->cityYes;
}

int bytecity_get_city_no(ByteCityHandle handle) {
    if (!handle) return 50;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    return 100 - (int)ctx->sim->cityYes;
}

void bytecity_trigger_disaster(ByteCityHandle handle, int disaster_id) {
    if (!handle) return;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    switch (disaster_id) {
        case DISASTER_FIRE: ctx->sim->makeFire(); break;
        case DISASTER_FLOOD: ctx->sim->makeFlood(); break;
        case DISASTER_MONSTER: ctx->sim->makeMonster(); break;
        case DISASTER_TORNADO: ctx->sim->makeTornado(); break;
        case DISASTER_EARTHQUAKE: ctx->sim->doEarthquake(6); break;
        case DISASTER_MELTDOWN: ctx->sim->makeMeltdown(); break;
    }
}

bool bytecity_has_message(ByteCityHandle handle) {
    if (!handle) return false;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    return !ctx->callback->messages.empty();
}

const char* bytecity_pop_message(ByteCityHandle handle) {
    if (!handle) return "";
    ByteCityContext* ctx = (ByteCityContext*)handle;
    if (ctx->callback->messages.empty()) return "";
    ctx->callback->current_message = ctx->callback->messages.front();
    ctx->callback->messages.pop();
    return ctx->callback->current_message.c_str();
}

bool bytecity_load_city(ByteCityHandle handle, const char* filepath) {
    if (!handle || !filepath) return false;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    bool ok = ctx->sim->loadFileData(filepath);
    if (ok) {
        ctx->sim->simUpdate();
    }
    return ok;
}

bool bytecity_save_city(ByteCityHandle handle, const char* filepath) {
    if (!handle || !filepath) return false;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    return ctx->sim->saveFile(filepath);
}

void bytecity_set_game_level(ByteCityHandle handle, int level) {
    if (!handle) return;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    ctx->sim->setGameLevel((GameLevel)level);
}

int bytecity_get_game_level(ByteCityHandle handle) {
    if (!handle) return 0;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    return (int)ctx->sim->gameLevel;
}

void bytecity_set_auto_bulldoze(ByteCityHandle handle, bool val) {
    if (!handle) return;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    ctx->sim->autoBulldoze = val;
}

bool bytecity_get_auto_bulldoze(ByteCityHandle handle) {
    if (!handle) return true;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    return ctx->sim->autoBulldoze;
}

void bytecity_set_auto_budget(ByteCityHandle handle, bool val) {
    if (!handle) return;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    ctx->sim->autoBudget = val;
}

bool bytecity_get_auto_budget(ByteCityHandle handle) {
    if (!handle) return false;
    ByteCityContext* ctx = (ByteCityContext*)handle;
    return ctx->sim->autoBudget;
}

static std::string g_city_name = "ByteCity";

void bytecity_set_city_name(ByteCityHandle handle, const char* name) {
    if (!name) return;
    g_city_name = name;
    if (handle) {
        ByteCityContext* ctx = (ByteCityContext*)handle;
        ctx->sim->setCityName(name);
    }
}

const char* bytecity_get_city_name(ByteCityHandle handle) {
    if (!handle) return g_city_name.c_str();
    ByteCityContext* ctx = (ByteCityContext*)handle;
    if (!ctx->sim->cityName.empty()) {
        g_city_name = ctx->sim->cityName;
    }
    return g_city_name.c_str();
}

} // extern "C"
