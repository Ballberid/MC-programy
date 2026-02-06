local ok, err = pcall(main)
if not ok then
  print("CHYBA:", err)
  print("Restart za 3s...")
  --redstone.setOutput("right", true)
  sleep(3)
  os.reboot()
end
end
