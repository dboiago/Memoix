import { useState } from "react";

const conversions = {
  volume: {
    units: ["ml", "l", "tsp", "tbsp", "cup", "fl oz", "pt", "qt", "gal"],
    toMl: {
      ml: 1,
      l: 1000,
      tsp: 4.92892,
      tbsp: 14.7868,
      cup: 236.588,
      "fl oz": 29.5735,
      pt: 473.176,
      qt: 946.353,
      gal: 3785.41,
    },
  },
  weight: {
    units: ["g", "kg", "oz", "lb", "mg"],
    toG: {
      g: 1,
      kg: 1000,
      oz: 28.3495,
      lb: 453.592,
      mg: 0.001,
    },
  },
  temperature: {
    units: ["°C", "°F", "K"],
  },
};

export function MeasurementConverter() {
  const [conversionType, setConversionType] = useState<"volume" | "weight" | "temperature">("volume");
  const [fromValue, setFromValue] = useState("");
  const [fromUnit, setFromUnit] = useState("cup");
  const [toUnit, setToUnit] = useState("ml");
  const [result, setResult] = useState("");

  const handleConvert = () => {
    const value = parseFloat(fromValue);
    if (isNaN(value)) {
      setResult("");
      return;
    }

    if (conversionType === "temperature") {
      let celsius: number;
      if (fromUnit === "°C") celsius = value;
      else if (fromUnit === "°F") celsius = ((value - 32) * 5) / 9;
      else celsius = value - 273.15;

      let converted: number;
      if (toUnit === "°C") converted = celsius;
      else if (toUnit === "°F") converted = (celsius * 9) / 5 + 32;
      else converted = celsius + 273.15;

      setResult(converted.toFixed(2));
    } else {
      const baseUnit = conversionType === "volume" ? "toMl" : "toG";
      const conversionsMap = conversions[conversionType][baseUnit] as Record<string, number>;
      const baseValue = value * conversionsMap[fromUnit];
      const converted = baseValue / conversionsMap[toUnit];
      setResult(converted.toFixed(2));
    }
  };

  const currentUnits = conversionType === "temperature" 
    ? conversions.temperature.units 
    : conversions[conversionType].units;

  return (
    <div className="space-y-6">
      <div>
        <label className="text-sm text-foreground">Conversion Type</label>
        <div className="flex gap-2 mt-2">
          {(["volume", "weight", "temperature"] as const).map((type) => (
            <button
              key={type}
              onClick={() => {
                setConversionType(type);
                setFromUnit(conversions[type].units[0]);
                setToUnit(conversions[type].units[1] || conversions[type].units[0]);
                setResult("");
              }}
              className={`flex-1 px-4 py-2 rounded-lg transition-colors ${
                conversionType === type
                  ? "bg-secondary text-secondary-foreground"
                  : "bg-card border border-border hover:bg-accent"
              }`}
            >
              {type.charAt(0).toUpperCase() + type.slice(1)}
            </button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="text-sm text-foreground">From</label>
          <input
            type="number"
            value={fromValue}
            onChange={(e) => {
              setFromValue(e.target.value);
              setResult("");
            }}
            placeholder="0"
            className="w-full mt-2 px-3 py-2 rounded-lg border border-border bg-card text-foreground"
          />
          <select
            value={fromUnit}
            onChange={(e) => {
              setFromUnit(e.target.value);
              setResult("");
            }}
            className="w-full mt-2 px-3 py-2 rounded-lg border border-border bg-card text-foreground"
          >
            {currentUnits.map((unit) => (
              <option key={unit} value={unit}>
                {unit}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="text-sm text-foreground">To</label>
          <input
            type="text"
            value={result}
            readOnly
            placeholder="Result"
            className="w-full mt-2 px-3 py-2 rounded-lg border border-border bg-muted text-foreground"
          />
          <select
            value={toUnit}
            onChange={(e) => {
              setToUnit(e.target.value);
              setResult("");
            }}
            className="w-full mt-2 px-3 py-2 rounded-lg border border-border bg-card text-foreground"
          >
            {currentUnits.map((unit) => (
              <option key={unit} value={unit}>
                {unit}
              </option>
            ))}
          </select>
        </div>
      </div>

      <button
        onClick={handleConvert}
        className="w-full py-3 bg-primary text-primary-foreground rounded-lg hover:opacity-90 transition-opacity"
      >
        Convert
      </button>
    </div>
  );
}