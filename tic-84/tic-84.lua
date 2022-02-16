-- tic84 - A tribute to the Amiga Boing ball demo shown at CES 1984
-- 256 byte intro for Lovebyte Battlegrounds 2021

ball_x = 200
ball_y = 100
ball_dx = 1

function TIC()
	for scr_y = 0, 135 do
		-- Texture coordinates are relative to ball position
		tex_y = ball_y - scr_y

		-- Roughly 40 pixels wide, slightly less for better shape
		y_sqr_dist_to_edge = 1550 - tex_y ^ 2

		for scr_x = 0, 225 do
			tex_x = ball_x - scr_x

			-- Background color: light (0) or shadow (2)
			color = tex_x ^ 2 < y_sqr_dist_to_edge and 2 or 0

			-- Squared distance from edge of ball to pixel
			-- Ball is shifted 20 pixels left from its shadow
			sqr_dist_to_edge = y_sqr_dist_to_edge - (tex_x - 20) ^ 2

			if scr_x % 15 == 0 or scr_y % 15 == 0 then
				-- Grid color: light (1) or shadow (3)
				color = color + 1
			end

			if sqr_dist_to_edge > 0 then
				-- Sphere mapping approximated as 1 / (5th root of sqr_dist_to_edge)
				-- A constant is added to avoid aliasing near the edge
				sphere_map = (sqr_dist_to_edge + 200) ^ -.2

				-- Checker pattern: (floor(tex_u / 5) + floor(tex_v / 5)) mod 2
				-- tex_u = cos(-30)*tex_x - sin(-30)*tex_y + ball_x/2 (to rotate along X axis as ball moves)
				-- tex_v = sin(-30)*tex_x + cos(-30)*tex_y
				-- cos(-30) = 0.866 approximated as 1.0
				-- sin(-30) = -0.5
				-- Ball color: red (4) or white (5)
				color = 4 + (((tex_x + tex_y / 2) * sphere_map - ball_x / 2) // 5 + (tex_y - tex_x / 2) * sphere_map // 5) % 2
			end

			pix(scr_x, scr_y, color)
		end
	end

	-- Ball is 40 pixels wide, 20 pixels left of shadow
	if ball_x < 60 or ball_x > 205 then
		ball_dx = -ball_dx
		volume = 16
	end

	-- Should be >(135-40)=95, approximated as >=100 for compression
	if ball_y >= 100 then
		ball_dy = -3
		volume = 16
	end

	ball_dy = ball_dy + .07
	ball_x = ball_x + ball_dx
	ball_y = ball_y + ball_dy

	-- Noise LFSR volume, hope we reset soon enough to not underflow!
	volume = volume - .2
	poke4(130875, volume)
end

-- <PALETTE>
-- 000:aaaaaaaa00aa666666660066ff0000ffffff000000000000000000000000000000000000000000000000000000000000
-- </PALETTE>
